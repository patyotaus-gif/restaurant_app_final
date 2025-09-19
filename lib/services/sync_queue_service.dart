import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  SyncQueueService(this._firestore, {Connectivity? connectivity})
    : _connectivity = connectivity ?? Connectivity() {
    _init();
  }

  static const _storageKey = 'sync_queue_operations_v1';

  final FirebaseFirestore _firestore;
  final Connectivity _connectivity;

  final List<QueuedOperation> _queue = [];
  final Map<String, Completer<SyncResult>> _pendingCompleters = {};

  SharedPreferences? _prefs;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

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
    final stored = _prefs!.getStringList(_storageKey) ?? [];
    _queue
      ..clear()
      ..addAll(
        stored.map((raw) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          return QueuedOperation.fromJson(decoded);
        }),
      );
    notifyListeners();
  }

  Future<void> _persistQueue() async {
    _prefs ??= await SharedPreferences.getInstance();
    final encoded = _queue.map((op) => jsonEncode(op.toJson())).toList();
    await _prefs!.setStringList(_storageKey, encoded);
  }

  void _updateConnectivityState(List<ConnectivityResult> results) {
    final newStatus = results.any(
      (result) => result != ConnectivityResult.none,
    );
    if (newStatus != _isOnline) {
      _isOnline = newStatus;
      notifyListeners();
    }
    if (_isOnline) {
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
    notifyListeners();

    final completer = Completer<SyncResult>();
    _pendingCompleters[operation.id] = completer;
    if (_isOnline) {
      unawaited(_processQueue());
      return completer.future;
    }

    return SyncResult(operationId: operation.id, isSynced: false);
  }

  Future<void> triggerSync() async {
    await _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing || !_isOnline || _queue.isEmpty) {
      return;
    }
    _isProcessing = true;
    notifyListeners();

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
        await _persistQueue();
        _lastSyncedAt = DateTime.now();
        _lastError = null;
        notifyListeners();

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
        notifyListeners();

        final completer = _pendingCompleters.remove(operation.id);
        if (completer != null && !completer.isCompleted) {
          completer.completeError(e);
        }
        break;
      }
    }

    _isProcessing = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
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
}
