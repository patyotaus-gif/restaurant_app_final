import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/store_model.dart';
import 'feature_flag_configuration.dart';
import 'feature_flag_scope.dart';
import 'feature_flag_service.dart';

class FeatureFlagProvider with ChangeNotifier {
  FeatureFlagProvider(this._featureFlagService);

  final FeatureFlagService _featureFlagService;

  FeatureFlagConfiguration _configuration = FeatureFlagConfiguration.empty();
  StreamSubscription<FeatureFlagConfiguration>? _subscription;

  String? _tenantId;
  String? _storeId;
  String? _terminalId;

  FeatureFlagConfiguration get configuration => _configuration;

  Map<String, bool> get activeFlags =>
      _configuration.effectiveFlags(storeId: _storeId, terminalId: _terminalId);

  bool isEnabled(String flag) {
    return _configuration.isEnabled(
      flag,
      storeId: _storeId,
      terminalId: _terminalId,
    );
  }

  void updateContext({required Store? store, required String? terminalId}) {
    final tenantId = store?.tenantId;
    final storeId = store?.id;

    final tenantChanged = _tenantId != tenantId;
    final storeChanged = _storeId != storeId;
    final terminalChanged = _terminalId != terminalId;

    if (tenantChanged) {
      _tenantId = tenantId;
      _configuration = FeatureFlagConfiguration.empty();
      _subscription?.cancel();
      if (tenantId != null) {
        _subscription = _featureFlagService.watchTenantFlags(tenantId).listen((
          configuration,
        ) {
          _configuration = configuration;
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

    if (tenantChanged || storeChanged || terminalChanged) {
      notifyListeners();
    }
  }

  Future<void> setFlag({
    required FeatureFlagScope scope,
    required String flag,
    required bool isEnabled,
    String? storeId,
    String? terminalId,
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
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
