import 'dart:async';
import 'dart:convert';

import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';

import '../services/offline_queue_encryption.dart';
import '../services/sync_queue_service.dart';

typedef EnsureFn = void Function();

/// Ensures that background isolates have all plugins registered. By default we
/// rely on [DartPluginRegistrant.ensureInitialized] so that platform channels
/// are wired up before any plugin is invoked from a background isolate. Tests
/// can override this function with a no-op if desired.
EnsureFn ensureBackgroundPlugins = DartPluginRegistrant.ensureInitialized;

RootIsolateToken? _rootIsolateToken;

/// Records the root isolate token so that it can be reused when the
/// background isolate is launched by Workmanager.
void configureBackgroundSync({RootIsolateToken? rootIsolateToken}) {
  _rootIsolateToken = rootIsolateToken;
}

const String backgroundSyncTaskName = 'pos.offline.sync.queue';
const String _periodicUniqueName = 'pos.offline.sync.periodic';
const String _oneOffUniqueName = 'pos.offline.sync.oneoff';

bool get _supportsBackgroundSync {
  if (kIsWeb) {
    return false;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
      return true;
    default:
      return false;
  }
}

bool supportsBackgroundSync() => _supportsBackgroundSync;

@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != backgroundSyncTaskName) {
      return Future.value(true);
    }
    try {
      WidgetsFlutterBinding.ensureInitialized();
      final token = _rootIsolateToken ?? ServicesBinding.rootIsolateToken;
      if (token != null) {
        BackgroundIsolateBinaryMessenger.ensureInitialized(token);
      }
      if (!_supportsBackgroundSync) {
        return true;
      }
      await BackgroundSyncManager.instance.ensureInitialized();
      ensureBackgroundPlugins();

      final executor = _BackgroundSyncExecutor();
      final success = await executor.run();
      return success;
    } catch (error, stackTrace) {
      debugPrint('Background sync failed: $error');
      debugPrint(stackTrace.toString());
      return false;
    }
  });
}

class BackgroundSyncManager {
  BackgroundSyncManager._();

  static final BackgroundSyncManager instance = BackgroundSyncManager._();

  bool _initialised = false;
  Completer<void>? _initialising;

  Future<void> ensureInitialized() async {
    if (!_supportsBackgroundSync) {
      return;
    }
    if (_initialised) {
      return;
    }
    if (_initialising != null) {
      await _initialising!.future;
      return;
    }
    _initialising = Completer<void>();
    try {
      await Workmanager().initialize(
        backgroundSyncDispatcher,
        isInDebugMode: kDebugMode,
      );
      _initialised = true;
      _initialising!.complete();
    } catch (error, stackTrace) {
      debugPrint('Failed to initialise Workmanager: $error');
      debugPrint(stackTrace.toString());
      _initialising!.completeError(error, stackTrace);
      rethrow;
    } finally {
      _initialising = null;
    }
  }

  Future<void> registerPeriodicSync() async {
    if (!_supportsBackgroundSync) {
      return;
    }
    await ensureInitialized();
    await Workmanager().registerPeriodicTask(
      _periodicUniqueName,
      backgroundSyncTaskName,
      frequency: const Duration(minutes: 15),
      existingWorkPolicy: ExistingWorkPolicy.keep,
      constraints: Constraints(networkType: NetworkType.connected),
      backoffPolicy: const BackoffPolicyConfig(
        policy: BackoffPolicy.exponential,
        delay: Duration(minutes: 5),
      ),
    );
  }

  Future<void> scheduleImmediateSync({Duration? delay}) async {
    if (!_supportsBackgroundSync) {
      return;
    }
    await ensureInitialized();
    await Workmanager().registerOneOffTask(
      _oneOffUniqueName,
      backgroundSyncTaskName,
      initialDelay: delay ?? Duration.zero,
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingWorkPolicy.replace,
      backoffPolicy: const BackoffPolicyConfig(
        policy: BackoffPolicy.exponential,
        delay: Duration(minutes: 2),
      ),
    );
  }
}

class _BackgroundSyncExecutor {
  _BackgroundSyncExecutor({OfflineQueueEncryption? encryption})
      : _encryption = encryption ?? OfflineQueueEncryption();

  final OfflineQueueEncryption _encryption;

  Future<bool> run() async {
    final prefs = await SharedPreferences.getInstance();
    final stored =
        prefs.getStringList(SyncQueueService.storageKey) ?? <String>[];
    if (stored.isEmpty) {
      return true;
    }

    final operations = <QueuedOperation>[];
    bool mutated = false;
    for (final raw in stored) {
      try {
        final decoded = await _encryption.decryptPayload(raw);
        operations.add(QueuedOperation.fromJson(decoded));
      } catch (error) {
        try {
          final legacy = SharedPreferencesJsonDecoder.tryDecode(raw);
          if (legacy != null) {
            operations.add(QueuedOperation.fromJson(legacy));
            mutated = true;
            continue;
          }
        } catch (_) {
          // Ignore legacy decode failure.
        }
        debugPrint('Dropping corrupted queued operation: $error');
        mutated = true;
      }
    }

    if (!mutated) {
      return true;
    }

    final encoded = <String>[];
    for (final operation in operations) {
      final encrypted = await _encryption.encryptPayload(operation.toJson());
      encoded.add(encrypted);
    }
    await prefs.setStringList(SyncQueueService.storageKey, encoded);
    return true;
  }
}

class SharedPreferencesJsonDecoder {
  static Map<String, dynamic>? tryDecode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      // Ignore
    }
    return null;
  }
}
