import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum OpsLogLevel { debug, info, warning, error }

class OpsLogEntry {
  OpsLogEntry({
    required this.level,
    required this.message,
    required this.timestamp,
    this.context,
    this.error,
    this.stackTrace,
  });

  final OpsLogLevel level;
  final String message;
  final DateTime timestamp;
  final Map<String, dynamic>? context;
  final String? error;
  final String? stackTrace;

  Map<String, dynamic> toFirestore() {
    return {
      'level': level.name,
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      if (context != null) 'context': context,
      if (error != null) 'error': error,
      if (stackTrace != null) 'stackTrace': stackTrace,
    };
  }
}

class OpsObservabilityService extends ChangeNotifier {
  OpsObservabilityService(this._firestore);

  final FirebaseFirestore _firestore;

  final List<OpsLogEntry> _entries = <OpsLogEntry>[];
  bool _overlayVisible = false;
  bool _remoteLoggingEnabled = true;

  List<OpsLogEntry> get entries => List.unmodifiable(_entries);
  bool get overlayVisible => _overlayVisible;
  bool get remoteLoggingEnabled => _remoteLoggingEnabled;

  set remoteLoggingEnabled(bool value) {
    if (_remoteLoggingEnabled == value) {
      return;
    }
    _remoteLoggingEnabled = value;
    notifyListeners();
  }

  Future<void> log(
    String message, {
    OpsLogLevel level = OpsLogLevel.info,
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
    bool sendRemote = true,
  }) async {
    final entry = OpsLogEntry(
      level: level,
      message: message,
      timestamp: DateTime.now(),
      context: context,
      error: error?.toString(),
      stackTrace: stackTrace?.toString(),
    );
    _entries.insert(0, entry);
    if (_entries.length > 200) {
      _entries.removeLast();
    }
    notifyListeners();

    if (_remoteLoggingEnabled && sendRemote) {
      try {
        await _firestore.collection('opsLogs').add(entry.toFirestore());
      } catch (e, st) {
        final fallback = OpsLogEntry(
          level: OpsLogLevel.error,
          message: 'Failed to send remote log: $e',
          timestamp: DateTime.now(),
          error: e.toString(),
          stackTrace: st.toString(),
        );
        _entries.insert(0, fallback);
        if (_entries.length > 200) {
          _entries.removeLast();
        }
        notifyListeners();
      }
    }
  }

  void toggleOverlay() {
    _overlayVisible = !_overlayVisible;
    notifyListeners();
  }

  void hideOverlay() {
    if (!_overlayVisible) {
      return;
    }
    _overlayVisible = false;
    notifyListeners();
  }

  void addLocalEntry(OpsLogEntry entry) {
    _entries.insert(0, entry);
    if (_entries.length > 200) {
      _entries.removeLast();
    }
    notifyListeners();
  }
}
