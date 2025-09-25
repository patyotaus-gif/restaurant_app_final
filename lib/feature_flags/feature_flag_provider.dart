import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/store_model.dart';
import '../services/client_cache_service.dart';
import 'feature_flag_configuration.dart';
import 'feature_flag_scope.dart';
import 'feature_flag_service.dart';
import 'release_environment.dart';

class FeatureFlagProvider with ChangeNotifier {
  FeatureFlagProvider(this._featureFlagService, this._cacheService);

  final FeatureFlagService _featureFlagService;
  final ClientCacheService _cacheService;

  FeatureFlagConfiguration _configuration = FeatureFlagConfiguration.empty();
  StreamSubscription<FeatureFlagConfiguration>? _subscription;

  String? _tenantId;
  String? _storeId;
  String? _terminalId;
  ReleaseEnvironment _baseEnvironment = ReleaseEnvironment.production;
  ReleaseEnvironment _environment = ReleaseEnvironment.production;
  String _releaseChannel = FeatureFlagConfiguration.defaultReleaseChannel;

  FeatureFlagConfiguration get configuration => _configuration;
  ReleaseEnvironment get environment => _environment;
  String get releaseChannel => _releaseChannel;

  Map<String, bool> get activeFlags => _configuration.effectiveFlags(
        storeId: _storeId,
        terminalId: _terminalId,
        environment: _environment,
        releaseChannel: _releaseChannel,
        rolloutUnitId: _rolloutUnitId,
      );

  bool isEnabled(String flag) {
    return _configuration.isEnabled(
      flag,
      storeId: _storeId,
      terminalId: _terminalId,
      environment: _environment,
      releaseChannel: _releaseChannel,
      rolloutUnitId: _rolloutUnitId,
    );
  }

  String get _rolloutUnitId =>
      _terminalId ?? _storeId ?? _tenantId ?? 'global';

  void updateContext({required Store? store, required String? terminalId}) {
    final tenantId = store?.tenantId;
    final storeId = store?.id;

    final tenantChanged = _tenantId != tenantId;
    final storeChanged = _storeId != storeId;
    final terminalChanged = _terminalId != terminalId;

    final newReleaseChannel = store?.releaseChannel ??
        FeatureFlagConfiguration.defaultReleaseChannel;
    final newBaseEnvironment = store?.releaseEnvironment ??
        ReleaseEnvironment.production;

    final channelChanged = _releaseChannel != newReleaseChannel;
    final environmentChanged = _baseEnvironment != newBaseEnvironment;

    if (tenantChanged) {
      _tenantId = tenantId;
      _configuration = FeatureFlagConfiguration.empty();
      _subscription?.cancel();
      if (tenantId != null) {
        _loadCachedConfiguration(tenantId);
        _subscription = _featureFlagService.watchTenantFlags(tenantId).listen((
          configuration,
        ) {
          _configuration = configuration;
          _recomputeEnvironment();
          unawaited(
            _cacheService.cacheFeatureFlags(
              tenantId: tenantId,
              configuration: configuration,
            ),
          );
          notifyListeners();
        });
      }
    }

    if (storeChanged) {
      _storeId = storeId;
    }

    if (terminalChanged) {
      _terminalId = terminalId;
    }

    if (channelChanged) {
      _releaseChannel = newReleaseChannel;
    }

    if (environmentChanged) {
      _baseEnvironment = newBaseEnvironment;
    }

    final envDidChange = _recomputeEnvironment();

    if (tenantChanged || storeChanged || terminalChanged || channelChanged ||
        environmentChanged || envDidChange) {
      notifyListeners();
    }
  }

  bool _recomputeEnvironment() {
    final resolved = _configuration.resolveEnvironment(
      _baseEnvironment,
      _releaseChannel,
    );
    if (_environment != resolved) {
      _environment = resolved;
      return true;
    }
    return false;
  }

  Future<void> _loadCachedConfiguration(String tenantId) async {
    final cached = await _cacheService.readFeatureFlags(tenantId: tenantId);
    if (cached != null && _tenantId == tenantId) {
      _configuration = cached;
      _recomputeEnvironment();
      notifyListeners();
    }
  }

  Future<void> setFlag({
    required FeatureFlagScope scope,
    required String flag,
    required bool isEnabled,
    String? storeId,
    String? terminalId,
    ReleaseEnvironment? environment,
    String? releaseChannel,
  }) async {
    final tenantId = _tenantId;
    if (tenantId == null) {
      throw StateError('Cannot modify feature flags without a tenant context.');
    }
    final resolvedStoreId = scope == FeatureFlagScope.store
        ? (storeId ?? _storeId)
        : storeId;
    final resolvedTerminalId = scope == FeatureFlagScope.terminal
        ? (terminalId ?? _terminalId)
        : terminalId;
    await _featureFlagService.setFlag(
      scope: scope,
      tenantId: tenantId,
      flag: flag,
      isEnabled: isEnabled,
      storeId: resolvedStoreId,
      terminalId: resolvedTerminalId,
      environment: environment,
      releaseChannel: releaseChannel,
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
