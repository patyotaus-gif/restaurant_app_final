library workmanager;

import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

const MethodChannel _foregroundChannel =
    MethodChannel('plugins.flutter.io/workmanager');
const MethodChannel _backgroundChannel =
    MethodChannel('plugins.flutter.io/workmanager_background');

/// Signature used when handling background work that was dispatched by the
/// native Android WorkManager.
typedef WorkmanagerTaskHandler = FutureOr<bool> Function(
  String taskName,
  Map<String, dynamic>? inputData,
);

WorkmanagerTaskHandler? _taskHandler;

/// Registry that keeps the current task handler.
Future<dynamic> _backgroundChannelHandler(MethodCall call) async {
  if (call.method != 'performTask') {
    throw PlatformException(
      code: 'unimplemented',
      message:
          'Method \'${call.method}\' is not supported on the background channel.',
    );
  }
  if (_taskHandler == null) {
    return false;
  }
  final arguments =
      Map<String, dynamic>.from(call.arguments as Map<dynamic, dynamic>);
  final task = arguments['taskName'] as String?;
  final rawInput = arguments['inputData'];
  Map<String, dynamic>? input;
  if (rawInput is Map) {
    input = Map<String, dynamic>.from(rawInput.cast<dynamic, dynamic>());
  } else if (rawInput is String && rawInput.isNotEmpty) {
    try {
      final decoded = json.decode(rawInput);
      if (decoded is Map<String, dynamic>) {
        input = decoded;
      }
    } on FormatException {
      // Ignore invalid payloads and keep [input] null.
    }
  }
  if (task == null) {
    return false;
  }
  final result = await _taskHandler!.call(task, input);
  return result == true;
}

/// A Dart wrapper around the platform Workmanager implementation.
class Workmanager {
  factory Workmanager() => _instance;

  Workmanager._internal() {
    // Ensure the background channel is configured when the library is loaded.
    _backgroundChannel.setMethodCallHandler(_backgroundChannelHandler);
  }

  static final Workmanager _instance = Workmanager._internal();

  /// Initializes the background dispatcher entry-point on the native side.
  Future<bool> initialize(
    Function callbackDispatcher, {
    bool isInDebugMode = false,
  }) async {
    final callbackHandle =
        PluginUtilities.getCallbackHandle(callbackDispatcher);
    if (callbackHandle == null) {
      throw ArgumentError(
        'Failed to obtain a callback handle for the provided dispatcher.',
      );
    }
    final result = await _foregroundChannel
        .invokeMethod<bool>('initialize', <String, dynamic>{
      'dispatcherHandle': callbackHandle.toRawHandle(),
      'isInDebugMode': isInDebugMode,
    });
    return result ?? false;
  }

  /// Registers the Dart [handler] to be invoked for background tasks.
  void executeTask(WorkmanagerTaskHandler handler) {
    _taskHandler = handler;
  }

  /// Registers a one-off task with the underlying WorkManager instance.
  Future<bool> registerOneOffTask(
    String uniqueName,
    String taskName, {
    Map<String, dynamic>? inputData,
    Duration? initialDelay,
    Constraints? constraints,
    ExistingWorkPolicy existingWorkPolicy = ExistingWorkPolicy.keep,
    BackoffPolicyConfig? backoffPolicy,
    List<String>? tags,
  }) async {
    final result = await _foregroundChannel
        .invokeMethod<bool>('registerOneOffTask', <String, dynamic>{
      'uniqueName': uniqueName,
      'taskName': taskName,
      'inputData': inputData,
      'initialDelayMillis': initialDelay?.inMilliseconds,
      'existingWorkPolicy': describeEnum(existingWorkPolicy),
      'constraints': constraints?.toJson(),
      'backoffPolicy': backoffPolicy?.toJson(),
      'tags': tags,
    });
    return result ?? false;
  }

  /// Registers a periodic task with the underlying WorkManager instance.
  Future<bool> registerPeriodicTask(
    String uniqueName,
    String taskName, {
    required Duration frequency,
    Duration? initialDelay,
    Map<String, dynamic>? inputData,
    Constraints? constraints,
    ExistingWorkPolicy existingWorkPolicy = ExistingWorkPolicy.keep,
    BackoffPolicyConfig? backoffPolicy,
    List<String>? tags,
  }) async {
    final result = await _foregroundChannel
        .invokeMethod<bool>('registerPeriodicTask', <String, dynamic>{
      'uniqueName': uniqueName,
      'taskName': taskName,
      'frequencyMillis': frequency.inMilliseconds,
      'initialDelayMillis': initialDelay?.inMilliseconds,
      'inputData': inputData,
      'constraints': constraints?.toJson(),
      'existingWorkPolicy': describeEnum(existingWorkPolicy),
      'backoffPolicy': backoffPolicy?.toJson(),
      'tags': tags,
    });
    return result ?? false;
  }

  /// Cancels all enqueued work.
  Future<void> cancelAll() =>
      _foregroundChannel.invokeMethod<void>('cancelAll');

  /// Cancels work identified by [uniqueName].
  Future<void> cancelByUniqueName(String uniqueName) =>
      _foregroundChannel.invokeMethod<void>('cancelByUniqueName', uniqueName);

  /// Cancels work matching the provided [tag].
  Future<void> cancelByTag(String tag) =>
      _foregroundChannel.invokeMethod<void>('cancelByTag', tag);
}

/// Defines how existing work should be treated when scheduling.
enum ExistingWorkPolicy {
  replace,
  keep,
  append,
}

/// Specifies the network requirements for the scheduled task.
enum NetworkType {
  notRequired,
  connected,
  unmetered,
  notRoaming,
  metered,
}

/// Configuration for retry backoff policies.
class BackoffPolicyConfig {
  const BackoffPolicyConfig({
    required this.policy,
    required this.delay,
  });

  final BackoffPolicy policy;
  final Duration delay;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'policy': describeEnum(policy),
        'delayMillis': delay.inMilliseconds,
      };
}

enum BackoffPolicy {
  exponential,
  linear,
}

/// Constraints used when scheduling tasks.
class Constraints {
  const Constraints({
    this.requiresCharging,
    this.requiresDeviceIdle,
    this.requiresBatteryNotLow,
    this.requiresStorageNotLow,
    this.networkType,
  });

  final bool? requiresCharging;
  final bool? requiresDeviceIdle;
  final bool? requiresBatteryNotLow;
  final bool? requiresStorageNotLow;
  final NetworkType? networkType;

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (requiresCharging != null) 'requiresCharging': requiresCharging,
        if (requiresDeviceIdle != null)
          'requiresDeviceIdle': requiresDeviceIdle,
        if (requiresBatteryNotLow != null)
          'requiresBatteryNotLow': requiresBatteryNotLow,
        if (requiresStorageNotLow != null)
          'requiresStorageNotLow': requiresStorageNotLow,
        if (networkType != null) 'networkType': describeEnum(networkType!),
      };
}
