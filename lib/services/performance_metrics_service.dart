import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Collects lightweight frame build/raster metrics and forwards summaries to
/// BigQuery via a callable Cloud Function.
class PerformanceMetricsService {
  PerformanceMetricsService(this._functions)
      : _sessionId =
            '${DateTime.now().millisecondsSinceEpoch}-${Random().nextInt(1 << 32)}';

  final FirebaseFunctions _functions;
  final List<FrameTiming> _buffer = <FrameTiming>[];
  final String _sessionId;
  DateTime _lastFlush = DateTime.now();
  late final TimingsCallback _callback = _handleTimings;
  bool _listening = false;
  bool _sending = false;
  String? _appVersion;

  /// Starts listening for frame timing updates.
  Future<void> start() async {
    if (_listening) {
      return;
    }
    _listening = true;
    try {
      final info = await PackageInfo.fromPlatform();
      _appVersion = '${info.version}+${info.buildNumber}';
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Failed to resolve package info: $error');
      }
    }
    SchedulerBinding.instance.addTimingsCallback(_callback);
  }

  void _handleTimings(List<FrameTiming> timings) {
    _buffer.addAll(timings);
    final now = DateTime.now();
    final shouldFlush =
        _buffer.length >= 120 || now.difference(_lastFlush).inSeconds >= 60;
    if (shouldFlush) {
      _lastFlush = now;
      unawaited(_flush());
    }
  }

  Future<void> _flush() async {
    if (_sending || _buffer.isEmpty) {
      return;
    }
    final frames = List<FrameTiming>.from(_buffer);
    _buffer.clear();
    _sending = true;

    try {
      final payload = _buildPayload(frames);
      await _functions.httpsCallable('ingestBuildMetric').call(payload);
    } catch (error, stackTrace) {
      if (kDebugMode) {
        debugPrint('PerformanceMetricsService failed to report metrics: $error');
        debugPrint(stackTrace.toString());
      }
    } finally {
      _sending = false;
    }
  }

  Map<String, dynamic> _buildPayload(List<FrameTiming> frames) {
    final buildDurationsMs = frames
        .map((frame) => frame.buildDuration.inMicroseconds / 1000)
        .toList(growable: false);
    final rasterDurationsMs = frames
        .map((frame) => frame.rasterDuration.inMicroseconds / 1000)
        .toList(growable: false);

    return <String, dynamic>{
      'sessionId': _sessionId,
      'timestamp': DateTime.now().toUtc().toIso8601String(),
      'appVersion': _appVersion,
      'buildMode': _buildModeLabel(),
      'platform': _platformLabel(),
      'frameCount': frames.length,
      'build': _summarize(buildDurationsMs),
      'raster': _summarize(rasterDurationsMs),
      if (kIsWeb) 'isWeb': true,
      'commit': const String.fromEnvironment('GIT_SHA', defaultValue: 'local'),
      'branch': const String.fromEnvironment('GIT_BRANCH', defaultValue: ''),
    };
  }

  Map<String, dynamic> _summarize(List<double> values) {
    if (values.isEmpty) {
      return <String, dynamic>{
        'average': 0,
        'p90': 0,
        'p99': 0,
        'max': 0,
      };
    }
    final sorted = List<double>.from(values)..sort();
    final sum = sorted.fold<double>(0, (total, value) => total + value);
    return <String, dynamic>{
      'average': sum / sorted.length,
      'p90': _percentile(sorted, 0.9),
      'p99': _percentile(sorted, 0.99),
      'max': sorted.last,
    };
  }

  double _percentile(List<double> sortedValues, double percentile) {
    if (sortedValues.isEmpty) {
      return 0;
    }
    final clamped = percentile.clamp(0, 1);
    final position = clamped * (sortedValues.length - 1);
    final lowerIndex = position.floor();
    final upperIndex = position.ceil();
    if (lowerIndex == upperIndex) {
      return sortedValues[lowerIndex];
    }
    final lower = sortedValues[lowerIndex];
    final upper = sortedValues[upperIndex];
    final fraction = position - lowerIndex;
    return lower + (upper - lower) * fraction;
  }

  String _buildModeLabel() {
    if (kReleaseMode) {
      return 'release';
    }
    if (kProfileMode) {
      return 'profile';
    }
    return 'debug';
  }

  String _platformLabel() {
    if (kIsWeb) {
      return 'web';
    }
    return defaultTargetPlatform.name;
  }

  /// Stops listening for frame metrics.
  void dispose() {
    if (!_listening) {
      return;
    }
    SchedulerBinding.instance.removeTimingsCallback(_callback);
    _listening = false;
  }
}
