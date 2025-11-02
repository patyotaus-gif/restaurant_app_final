import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../notifications_repository.dart';
import 'ops_observability_service.dart';
import 'printer_drawer_service.dart';

final Random _printJobRandom = Random();

enum PrintJobType { receipt }

enum PrintJobStatus {
  queued,
  printing,
  retryScheduled,
  success,
  failed,
  cancelled,
}

class PrintJobSnapshot {
  const PrintJobSnapshot({
    required this.id,
    required this.type,
    required this.status,
    required this.attempts,
    required this.createdAt,
    required this.nextRunAt,
    this.lastError,
    this.metadata = const <String, dynamic>{},
  });

  final String id;
  final PrintJobType type;
  final PrintJobStatus status;
  final int attempts;
  final DateTime createdAt;
  final DateTime nextRunAt;
  final String? lastError;
  final Map<String, dynamic> metadata;
}

enum PrintSpoolerAlertSeverity { info, warning, error }

class PrintSpoolerAlert {
  const PrintSpoolerAlert({
    required this.severity,
    required this.title,
    required this.message,
    required this.timestamp,
  });

  final PrintSpoolerAlertSeverity severity;
  final String title;
  final String message;
  final DateTime timestamp;
}

class PrintSpoolerHealth {
  const PrintSpoolerHealth({
    required this.isHealthy,
    required this.pendingJobs,
    required this.retryingJobs,
    required this.failedJobs,
    required this.lastUpdated,
    this.latestAlert,
  });

  factory PrintSpoolerHealth.healthy() => PrintSpoolerHealth(
    isHealthy: true,
    pendingJobs: 0,
    retryingJobs: 0,
    failedJobs: 0,
    lastUpdated: DateTime.fromMillisecondsSinceEpoch(0),
    latestAlert: null,
  );

  final bool isHealthy;
  final int pendingJobs;
  final int retryingJobs;
  final int failedJobs;
  final DateTime lastUpdated;
  final PrintSpoolerAlert? latestAlert;
}

class ReceiptPrintJobPayload {
  const ReceiptPrintJobPayload({
    required this.host,
    required this.port,
    required this.orderData,
    required this.storeDetails,
    this.taxDetails,
    this.openDrawer = false,
  });

  final String host;
  final int port;
  final Map<String, dynamic> orderData;
  final StoreReceiptDetails storeDetails;
  final TaxInvoiceDetails? taxDetails;
  final bool openDrawer;

  String? get orderIdentifier =>
      orderData['orderIdentifier']?.toString() ?? orderData['id']?.toString();
}

class PrintSpoolerService extends ChangeNotifier {
  PrintSpoolerService({
    required PrinterDrawerService printerService,
    NotificationsRepository? notificationsRepository,
    OpsObservabilityService? observability,
    Duration healthCheckInterval = const Duration(seconds: 30),
  }) : _printerService = printerService,
       _notificationsRepository = notificationsRepository,
       _observability = observability,
       _healthCheckInterval = healthCheckInterval {
    _healthTimer = Timer.periodic(
      _healthCheckInterval,
      (_) => _evaluateHealth(),
    );
    _evaluateHealth();
  }

  static const int _maxAttempts = 4;
  static const int _alertHistoryLimit = 20;

  final PrinterDrawerService _printerService;
  NotificationsRepository? _notificationsRepository;
  OpsObservabilityService? _observability;
  final Duration _healthCheckInterval;

  final List<_PrintJob> _queue = <_PrintJob>[];
  final List<_PrintJob> _failedJobs = <_PrintJob>[];
  final List<PrintSpoolerAlert> _alerts = <PrintSpoolerAlert>[];
  _PrintJob? _activeJob;
  PrintSpoolerHealth _health = PrintSpoolerHealth.healthy();
  Timer? _healthTimer;
  Timer? _scheduledTimer;
  bool _isProcessing = false;
  String? _tenantId;
  String? _storeId;

  List<PrintJobSnapshot> get queue =>
      _queue.map(_snapshotFromJob).toList(growable: false);
  List<PrintJobSnapshot> get failedJobs =>
      _failedJobs.map(_snapshotFromJob).toList(growable: false);
  PrintJobSnapshot? get activeJob =>
      _activeJob != null ? _snapshotFromJob(_activeJob!) : null;
  PrintSpoolerHealth get health => _health;
  List<PrintSpoolerAlert> get alerts =>
      List<PrintSpoolerAlert>.unmodifiable(_alerts);

  void updateContext({String? tenantId, String? storeId}) {
    _tenantId = tenantId;
    _storeId = storeId;
  }

  void updateNotificationsRepository(NotificationsRepository repository) {
    _notificationsRepository = repository;
  }

  void attachObservability(OpsObservabilityService? service) {
    _observability = service;
  }

  Future<void> enqueueReceipt({
    required String host,
    required int port,
    required Map<String, dynamic> orderData,
    required StoreReceiptDetails storeDetails,
    TaxInvoiceDetails? taxDetails,
    bool openDrawer = false,
  }) {
    final payload = ReceiptPrintJobPayload(
      host: host,
      port: port,
      orderData: orderData,
      storeDetails: storeDetails,
      taxDetails: taxDetails,
      openDrawer: openDrawer,
    );
    final job = _PrintJob.receipt(payload);
    _queue.add(job);
    _observability?.log(
      'Print job queued',
      level: OpsLogLevel.debug,
      context: {'jobId': job.id, 'type': job.type.name, 'host': host},
      sendRemote: false,
    );
    notifyListeners();
    _scheduleProcessing();
    _evaluateHealth();
    return job.completer.future;
  }

  void cancelAll() {
    for (final job in _queue) {
      if (!job.completer.isCompleted) {
        job.completer.completeError(
          StateError('Print job was cancelled before execution'),
        );
      }
    }
    _queue.clear();
    _scheduledTimer?.cancel();
    _evaluateHealth();
    notifyListeners();
  }

  @override
  void dispose() {
    _scheduledTimer?.cancel();
    _healthTimer?.cancel();
    super.dispose();
  }

  void _scheduleProcessing() {
    if (_isProcessing) {
      return;
    }
    _scheduledTimer?.cancel();
    if (_queue.isEmpty) {
      return;
    }
    _queue.sort((a, b) => a.nextRunAt.compareTo(b.nextRunAt));
    final nextJob = _queue.first;
    final now = DateTime.now();
    final delay = nextJob.nextRunAt.difference(now);
    if (delay.isNegative || delay == Duration.zero) {
      unawaited(_processNextJob());
    } else {
      _scheduledTimer = Timer(delay, () => _processNextJob());
    }
  }

  Future<void> _processNextJob() async {
    if (_isProcessing || _queue.isEmpty) {
      return;
    }
    _queue.sort((a, b) => a.nextRunAt.compareTo(b.nextRunAt));
    final job = _queue.first;
    final now = DateTime.now();
    if (job.nextRunAt.isAfter(now)) {
      _scheduledTimer = Timer(
        job.nextRunAt.difference(now),
        () => _processNextJob(),
      );
      return;
    }
    _isProcessing = true;
    _activeJob = job;
    job.status = PrintJobStatus.printing;
    notifyListeners();
    try {
      await _executeJob(job);
      job.status = PrintJobStatus.success;
      _queue.remove(job);
      final metadata = job.metadata;
      _observability?.log(
        'Print job completed',
        level: OpsLogLevel.info,
        context: {
          'jobId': job.id,
          'type': job.type.name,
          if (metadata['host'] != null) 'host': metadata['host'],
          if (metadata['orderIdentifier'] != null)
            'orderIdentifier': metadata['orderIdentifier'],
        },
        sendRemote: false,
      );
      if (!job.completer.isCompleted) {
        job.completer.complete();
      }
    } catch (error, stackTrace) {
      job.attempts += 1;
      job.lastError = error.toString();
      if (job.attempts >= _maxAttempts) {
        job.status = PrintJobStatus.failed;
        _queue.remove(job);
        _failedJobs.insert(0, job);
        if (_failedJobs.length > _alertHistoryLimit) {
          _failedJobs.removeLast();
        }
        if (!job.completer.isCompleted) {
          job.completer.completeError(error);
        }
        await _handleFinalFailure(job, error, stackTrace);
      } else {
        final backoffSeconds = min(300, (pow(2, job.attempts) * 5).round());
        job.nextRunAt = DateTime.now().add(Duration(seconds: backoffSeconds));
        job.status = PrintJobStatus.retryScheduled;
        _observability?.log(
          'Print job retry scheduled',
          level: OpsLogLevel.warning,
          context: {
            'jobId': job.id,
            'type': job.type.name,
            'attempts': job.attempts,
            'nextRunAt': job.nextRunAt.toIso8601String(),
          },
          error: error,
          stackTrace: stackTrace,
          sendRemote: false,
        );
      }
    } finally {
      _activeJob = null;
      _isProcessing = false;
      notifyListeners();
      _evaluateHealth();
      _scheduleProcessing();
    }
  }

  Future<void> _executeJob(_PrintJob job) async {
    switch (job.type) {
      case PrintJobType.receipt:
        final payload = job.payload as ReceiptPrintJobPayload;
        await _printerService.printReceipt(
          host: payload.host,
          port: payload.port,
          orderData: payload.orderData,
          storeDetails: payload.storeDetails,
          taxDetails: payload.taxDetails,
        );
        return;
    }
  }

  Future<void> _handleFinalFailure(
    _PrintJob job,
    Object error,
    StackTrace stackTrace,
  ) async {
    final payload = job.payload is ReceiptPrintJobPayload
        ? job.payload as ReceiptPrintJobPayload
        : null;
    final orderIdentifier = payload?.orderIdentifier;
    final host = payload?.host;
    final message = orderIdentifier == null
        ? 'ไม่สามารถพิมพ์งานได้หลังจากพยายาม ${job.attempts} ครั้ง'
        : 'ไม่สามารถพิมพ์ใบเสร็จ $orderIdentifier ได้หลังจากพยายาม ${job.attempts} ครั้ง';
    final alert = PrintSpoolerAlert(
      severity: PrintSpoolerAlertSeverity.error,
      title: 'พิมพ์ใบเสร็จไม่สำเร็จ',
      message: message,
      timestamp: DateTime.now(),
    );
    _pushAlert(alert);
    _observability?.log(
      'Print job failed permanently',
      level: OpsLogLevel.error,
      context: {
        'jobId': job.id,
        'type': job.type.name,
        if (orderIdentifier != null) 'orderIdentifier': orderIdentifier,
        if (host != null) 'host': host,
        'attempts': job.attempts,
      },
      error: error,
      stackTrace: stackTrace,
      sendRemote: true,
    );
    final tenantId = _tenantId;
    final repository = _notificationsRepository;
    if (tenantId != null && repository != null) {
      try {
        await repository.publishSystemNotification(
          tenantId: tenantId,
          title: 'ปัญหาการพิมพ์ใบเสร็จ',
          message: message,
          severity: 'error',
          data: {
            'jobId': job.id,
            'type': job.type.name,
            if (orderIdentifier != null) 'orderIdentifier': orderIdentifier,
            if (host != null) 'host': host,
            if (_storeId != null) 'storeId': _storeId,
            'attempts': job.attempts,
          },
        );
      } catch (notificationError, notificationStack) {
        debugPrint(
          'Failed to push print failure notification: $notificationError',
        );
        _observability?.log(
          'Failed to record print failure notification',
          level: OpsLogLevel.error,
          error: notificationError,
          stackTrace: notificationStack,
          sendRemote: false,
        );
      }
    }
  }

  void _evaluateHealth() {
    final now = DateTime.now();
    final pending = _queue.length;
    final retrying = _queue
        .where((job) => job.status == PrintJobStatus.retryScheduled)
        .length;
    final failed = _failedJobs.length;
    PrintSpoolerAlert? latestAlert;
    if (failed > 0) {
      latestAlert = PrintSpoolerAlert(
        severity: PrintSpoolerAlertSeverity.error,
        title: 'คิวพิมพ์มีงานล้มเหลว',
        message: 'มีงานพิมพ์ล้มเหลว ${failed.toString()} งาน',
        timestamp: now,
      );
      _pushAlert(latestAlert);
    } else if (pending > 3 || retrying > 0) {
      latestAlert = PrintSpoolerAlert(
        severity: PrintSpoolerAlertSeverity.warning,
        title: 'คิวพิมพ์กำลังรอ',
        message: 'มีงานพิมพ์รออยู่ ${pending.toString()} งาน',
        timestamp: now,
      );
      _pushAlert(latestAlert);
    }
    _health = PrintSpoolerHealth(
      isHealthy: failed == 0 && retrying == 0,
      pendingJobs: pending,
      retryingJobs: retrying,
      failedJobs: failed,
      lastUpdated: now,
      latestAlert: latestAlert ?? (_alerts.isNotEmpty ? _alerts.first : null),
    );
    notifyListeners();
  }

  void _pushAlert(PrintSpoolerAlert alert) {
    if (_alerts.isNotEmpty) {
      final latest = _alerts.first;
      if (latest.message == alert.message &&
          latest.severity == alert.severity) {
        return;
      }
    }
    _alerts.insert(0, alert);
    if (_alerts.length > _alertHistoryLimit) {
      _alerts.removeLast();
    }
  }

  PrintJobSnapshot _snapshotFromJob(_PrintJob job) {
    return PrintJobSnapshot(
      id: job.id,
      type: job.type,
      status: job.status,
      attempts: job.attempts,
      createdAt: job.createdAt,
      nextRunAt: job.nextRunAt,
      lastError: job.lastError,
      metadata: job.metadata,
    );
  }
}

class _PrintJob {
  _PrintJob.receipt(this.payload)
    : id = _generateId(),
      type = PrintJobType.receipt,
      createdAt = DateTime.now(),
      nextRunAt = DateTime.now();

  final String id;
  final PrintJobType type;
  final Object payload;
  final DateTime createdAt;
  DateTime nextRunAt;
  int attempts = 0;
  PrintJobStatus status = PrintJobStatus.queued;
  String? lastError;
  final Completer<void> completer = Completer<void>();

  Map<String, dynamic> get metadata {
    if (payload is ReceiptPrintJobPayload) {
      final data = payload as ReceiptPrintJobPayload;
      return {
        'host': data.host,
        'port': data.port,
        if (data.orderIdentifier != null)
          'orderIdentifier': data.orderIdentifier,
      };
    }
    return const <String, dynamic>{};
  }

  static String _generateId() {
    final millis = DateTime.now().millisecondsSinceEpoch;
    final rand = _printJobRandom.nextInt(1 << 32);
    return 'print-$millis-$rand';
  }
}
