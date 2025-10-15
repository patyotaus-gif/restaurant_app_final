import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'offline_queue_encryption.dart';
import 'ops_observability_service.dart';
class SyncResult {
  final String operationId;
  final bool isSynced;
  final String? remoteDocumentId;

  const SyncResult({
    required this.operationId,
    required this.isSynced,
    this.remoteDocumentId,
  });
}

class QueuedOperation {
  QueuedOperation({
    required this.id,
    required this.collectionPath,
    required this.type,
    required this.payload,
    required this.createdAt,
    this.documentId,
  });

  factory QueuedOperation.add({
    required String collectionPath,
    required Map<String, dynamic> data,
  }) {
    final now = DateTime.now();
    final random = Random().nextInt(1 << 32);
    return QueuedOperation(
      id: '${now.millisecondsSinceEpoch}-$random',
      collectionPath: collectionPath,
      type: 'add',
      payload: _normalizeMap(data),
      createdAt: now,
    );
  }

  final String id;
  final String collectionPath;
  final String type;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final String? documentId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'collectionPath': collectionPath,
    'type': type,
    'payload': payload,
    'createdAt': createdAt.toIso8601String(),
    'documentId': documentId,
  };

  factory QueuedOperation.fromJson(Map<String, dynamic> json) {
    return QueuedOperation(
      id: json['id'] as String,
      collectionPath: json['collectionPath'] as String,
      type: json['type'] as String,
      payload: Map<String, dynamic>.from(
        json['payload'] as Map<String, dynamic>,
      ),
      createdAt:
          DateTime.tryParse(json['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      documentId: json['documentId'] as String?,
    );
  }

  Map<String, dynamic> toFirestoreData() {
    return _restoreMap(payload);
  }

  static Map<String, dynamic> _normalizeMap(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key, _normalizeValue(value)));
  }

  static dynamic _normalizeValue(dynamic value) {
    if (value is Timestamp) {
      return {
        '__type': 'timestamp',
        'seconds': value.seconds,
        'nanoseconds': value.nanoseconds,
      };
    }
    if (value is DateTime) {
      return {'__type': 'datetime', 'iso': value.toIso8601String()};
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _normalizeValue(v)));
    }
    if (value is Iterable) {
      return value.map(_normalizeValue).toList();
    }
    return value;
  }

  static Map<String, dynamic> _restoreMap(Map<String, dynamic> input) {
    return input.map((key, value) => MapEntry(key, _restoreValue(value)));
  }

  static dynamic _restoreValue(dynamic value) {
    if (value is Map<String, dynamic> && value['__type'] != null) {
      switch (value['__type']) {
        case 'timestamp':
          return Timestamp(
            value['seconds'] as int? ?? 0,
            value['nanoseconds'] as int? ?? 0,
          );
        case 'datetime':
          final iso = value['iso'] as String?;
          return iso != null ? DateTime.tryParse(iso) : null;
      }
    }
    if (value is Map<String, dynamic>) {
      return value.map((k, v) => MapEntry(k, _restoreValue(v)));
    }
    if (value is List) {
      return value.map(_restoreValue).toList();
    }
    return value;
  }
}

class SyncQueueService extends ChangeNotifier {
  SyncQueueService(
    this._firestore, {
    Connectivity? connectivity,
    OpsObservabilityService? observability,
  })  : _connectivity = connectivity ?? Connectivity(),
        _observability = observability {
    _init();
  }

  static const storageKey = 'sync_queue_operations_v1';

  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;
  final OfflineQueueEncryption _encryption = OfflineQueueEncryption();

  final List<QueuedOperation> _queue = [];
  final Map<String, Completer<SyncResult>> _pendingCompleters = {};
  Future<void> Function({Duration? delay})? _backgroundSyncScheduler;

  /// Exponential backoff state used to avoid hammering Firestore when
  /// connectivity is flaky. Firestore resolves writes immediately even when
  /// offline, so without throttling the queue can enqueue more than the maximum
  /// number of pending writes which triggers
  /// "Write stream exhausted maximum allowed queued writes" errors.
  Duration _currentRetryDelay = Duration.zero;
  Timer? _retryTimer;

  SharedPreferences? _prefs;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  OpsObservabilityService? _observability;

  bool _isOnline = true;
  bool _isProcessing = false;
  DateTime? _lastSyncedAt;
  String? _lastError;

  bool get isOnline => _isOnline;
  int get pendingCount => _queue.length;
  bool get isProcessing => _isProcessing;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  String? get lastError => _lastError;

  Future<void> _init() async {
    await _loadQueue();
    final current = await _connectivity.checkConnectivity();
    _updateConnectivityState(current);
    _connectivitySub = _connectivity.onConnectivityChanged.listen(
      _updateConnectivityState,
    );
    if (_isOnline) {
      unawaited(_processQueue());
    }
  }

  Future<void> _loadQueue() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs!.getStringList(storageKey) ?? [];
    final List<QueuedOperation> decodedOperations = [];
    bool needsMigration = false;
    for (final raw in stored) {
      try {
        final decoded = await _encryption.decryptPayload(raw);
        decodedOperations.add(QueuedOperation.fromJson(decoded));
      } catch (error, stackTrace) {
        needsMigration = true;
        try {
          final legacy = jsonDecode(raw);
          if (legacy is Map<String, dynamic>) {
            decodedOperations.add(QueuedOperation.fromJson(legacy));
            continue;
          }
        } catch (_) {
          // Ignore – handled below.
        }
        _recordObservability(
          'Failed to decode queued operation',
          level: OpsLogLevel.error,
          error: error,
          stackTrace: stackTrace,
          sendRemote: true,
        );
      }
    }
    _queue
      ..clear()
      ..addAll(decodedOperations);
    _safeNotifyListeners();

    if (_queue.isNotEmpty) {
      _requestBackgroundSync();
    }

    if (needsMigration && _queue.isNotEmpty) {
      await _persistQueue();
      _recordObservability(
        'Migrated ${_queue.length} queued operations to encrypted storage',
        level: OpsLogLevel.info,
      );
    }
  }

  Future<void> _persistQueue() async {
    _prefs ??= await SharedPreferences.getInstance();
    final encoded = <String>[];
    for (final op in _queue) {
      final encrypted = await _encryption.encryptPayload(op.toJson());
      encoded.add(encrypted);
    }
    await _prefs!.setStringList(storageKey, encoded);
  }

  void _updateConnectivityState(List<ConnectivityResult> results) {
    final newStatus = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (newStatus != _isOnline) {
      _isOnline = newStatus;
      _safeNotifyListeners();
    }
    if (_isOnline) {
      _clearRetryBackoff();
      unawaited(_processQueue());
    }
  }

  Future<SyncResult> enqueueAdd(
    String collectionPath,
    Map<String, dynamic> data,
  ) async {
    final operation = QueuedOperation.add(
      collectionPath: collectionPath,
      data: data,
    );
    _queue.add(operation);
    await _persistQueue();
    _requestBackgroundSync();
    _safeNotifyListeners();

    _recordObservability(
      'Operation queued for offline sync',
      level: OpsLogLevel.debug,
      context: {
        'operationId': operation.id,
        'collection': collectionPath,
        'pending': _queue.length,
      },
      sendRemote: false,
    );

    final completer = Completer<SyncResult>();
    _pendingCompleters[operation.id] = completer;
    if (_isOnline) {
      unawaited(_processQueue());
      return completer.future;
    }

    return SyncResult(operationId: operation.id, isSynced: false);
  }

  Future<void> triggerSync() async {
    await _processQueue(force: true);
  }

  void attachBackgroundSyncScheduler(
    Future<void> Function({Duration? delay})? scheduler,
  ) {
    _backgroundSyncScheduler = scheduler;
  }

  void _requestBackgroundSync() {
    final scheduler = _backgroundSyncScheduler;
    if (scheduler == null) {
      return;
    }
    unawaited(scheduler());
  }

  Future<void> _processQueue({bool force = false}) async {
    if (!force && _retryTimer != null) {
      return;
    }
    if (force && _retryTimer != null) {
      _retryTimer!.cancel();
      _retryTimer = null;
    }
    if (_isProcessing || !_isOnline || _queue.isEmpty) {
      return;
    }
    _isProcessing = true;
    _safeNotifyListeners();

    while (_queue.isNotEmpty && _isOnline) {
      final operation = _queue.first;
      try {
        String? remoteId;
        switch (operation.type) {
          case 'add':
            final data = operation.toFirestoreData();
            final docRef = await _firestore
                .collection(operation.collectionPath)
                .add(data);
            remoteId = docRef.id;
            break;
          default:
            throw UnsupportedError(
              'Unsupported operation type: ${operation.type}',
            );
        }

        _queue.removeAt(0);
        _clearRetryBackoff();
        await _persistQueue();
        _lastSyncedAt = DateTime.now();
        _lastError = null;
        _safeNotifyListeners();

        _recordObservability(
          'Queued operation synced',
          level: OpsLogLevel.info,
          context: {
            'operationId': operation.id,
            'collection': operation.collectionPath,
            'type': operation.type,
            'pending': _queue.length,
          },
          sendRemote: false,
        );

        final completer = _pendingCompleters.remove(operation.id);
        completer?.complete(
          SyncResult(
            operationId: operation.id,
            isSynced: true,
            remoteDocumentId: remoteId,
          ),
        );
      } catch (e, stackTrace) {
        _lastError = e.toString();
        debugPrint('SyncQueue error for ${operation.id}: $e');
        debugPrint(stackTrace.toString());
        _safeNotifyListeners();

        if (_shouldBackoff(e)) {
          _scheduleRetry();
        } else {
          _requestBackgroundSync();
        }

        _recordObservability(
          'Failed to sync queued operation',
          level: OpsLogLevel.error,
          context: {
            'operationId': operation.id,
            'collection': operation.collectionPath,
            'type': operation.type,
          },
          error: e,
          stackTrace: stackTrace,
          sendRemote: true,
        );

        final completer = _pendingCompleters.remove(operation.id);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(e);
        }
        break;
      }
    }

    _isProcessing = false;
    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _retryTimer?.cancel();
    _pendingCompleters.forEach((operationId, completer) {
      if (!completer.isCompleted) {
        completer.complete(
          SyncResult(operationId: operationId, isSynced: false),
        );
      }
    });
    _pendingCompleters.clear();
    super.dispose();
  }

  void _safeNotifyListeners() {
    final scheduler = SchedulerBinding.instance;
    if (scheduler == null) {
      notifyListeners();
      return;
    }

    final phase = scheduler.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else {
      scheduler.addPostFrameCallback((_) => notifyListeners());
    }
  }

  void _recordObservability(
    String message, {
    OpsLogLevel level = OpsLogLevel.info,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    bool sendRemote = false,
  }) {
    final service = _observability;
    if (service == null) {
      return;
    }
    unawaited(
      service.log(
        message,
        level: level,
        context: context,
        error: error,
        stackTrace: stackTrace,
        sendRemote: sendRemote,
      ),
    );
  }

  void _clearRetryBackoff() {
    if (_currentRetryDelay == Duration.zero && _retryTimer == null) {
      return;
    }
    _currentRetryDelay = Duration.zero;
    _retryTimer?.cancel();
    _retryTimer = null;
  }

  bool _shouldBackoff(Object error) {
    if (error is FirebaseException && error.plugin == 'cloud_firestore') {
      const backoffCodes = {
        'resource-exhausted',
        'unavailable',
        'deadline-exceeded',
        'internal',
      };
      if (backoffCodes.contains(error.code)) {
        return true;
      }
      final message = error.message?.toLowerCase();
      if (message != null &&
          (message.contains('maximum allowed queued writes') ||
              message.contains('connection reset') ||
              message.contains('stream disconnected') ||
              message.contains('failed to get document because the client is offline'))) {
        return true;
      }
    }
    if (error is TimeoutException) {
      return true;
    }
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('connection reset') ||
        errorString.contains('timed out') ||
        errorString.contains('broken pipe')) {
      return true;
    }
    return false;
  }

  void _scheduleRetry() {
    final previous = _currentRetryDelay;
    final nextDelay = previous == Duration.zero
        ? const Duration(seconds: 2)
        : Duration(
            milliseconds: min(
              previous.inMilliseconds * 2,
              const Duration(minutes: 1).inMilliseconds,
            ),
          );
    _currentRetryDelay = nextDelay;
    _retryTimer?.cancel();
    _retryTimer = Timer(nextDelay, () {
      _retryTimer = null;
      if (_isOnline && _queue.isNotEmpty) {
        unawaited(_processQueue());
      }
    });

    _recordObservability(
      'Scheduled sync queue retry',
      level: OpsLogLevel.debug,
      context: {
        'delayMs': nextDelay.inMilliseconds,
        'pending': _queue.length,
      },
      sendRemote: false,
    );
  }

  Future<void> rotateEncryptionKey() async {
    _prefs ??= await SharedPreferences.getInstance();
    final stored = _prefs!.getStringList(storageKey) ?? [];
    if (stored.isEmpty) {
      _recordObservability(
        'Queue encryption key rotated (no pending payloads)',
        level: OpsLogLevel.debug,
        sendRemote: false,
      );
      return;
    }
    final reencrypted = await _encryption.rotateKeyAndReencrypt(stored);
    await _prefs!.setStringList(storageKey, reencrypted);
    _recordObservability(
      'Queue encryption key rotated',
      level: OpsLogLevel.info,
      context: {'payloads': reencrypted.length},
      sendRemote: false,
    );
  }

  void attachObservability(OpsObservabilityService? service) {
    _observability = service;
  }
}
