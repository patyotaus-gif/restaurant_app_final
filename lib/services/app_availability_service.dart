import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';

import 'ops_observability_service.dart';

enum AppAvailabilityStatus { checking, available, blocked }

class AppAvailabilityService extends ChangeNotifier {
  AppAvailabilityService(
    FirebaseRemoteConfig? remoteConfig,
    this._observability,
    this._buildNumber,
  ) : _remoteConfig = remoteConfig;

  final FirebaseRemoteConfig? _remoteConfig;
  final OpsObservabilityService _observability;
  final String _buildNumber;

  AppAvailabilityStatus _status = AppAvailabilityStatus.checking;
  String? _message;

  AppAvailabilityStatus get status => _status;
  String? get message => _message;

  Future<void> initialize() async {
    final remoteConfig = _remoteConfig;
    if (remoteConfig == null) {
      _status = AppAvailabilityStatus.available;
      _message = null;
      notifyListeners();
      return;
    }

    try {
      await remoteConfig.ensureInitialized();
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ));
      await remoteConfig.setDefaults(const {
        'minimum_supported_build': 1,
        'kill_switch_enabled': false,
        'kill_switch_message': '',
      });

      await remoteConfig.fetchAndActivate();

      final bool killSwitchEnabled =
          remoteConfig.getBool('kill_switch_enabled');
      final int minimumSupportedBuild =
          remoteConfig.getInt('minimum_supported_build');
      final String configuredMessage =
          remoteConfig.getString('kill_switch_message').trim();

      final int currentBuild = int.tryParse(_buildNumber) ?? 0;

      if (killSwitchEnabled && currentBuild < minimumSupportedBuild) {
        _status = AppAvailabilityStatus.blocked;
        _message = configuredMessage.isNotEmpty
            ? configuredMessage
            : 'This version of the app is no longer supported. '
                'Please update to continue using the service.';
      } else {
        _status = AppAvailabilityStatus.available;
        _message = null;
      }
    } catch (error, stackTrace) {
      await _observability.log(
        'Failed to evaluate Remote Config kill switch',
        level: OpsLogLevel.error,
        error: error,
        stackTrace: stackTrace,
      );
      _status = AppAvailabilityStatus.available;
      _message = null;
    }

    notifyListeners();
  }
}
