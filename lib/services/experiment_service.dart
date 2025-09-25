import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../feature_flags/feature_flag_configuration.dart';
class ExperimentService extends ChangeNotifier {
  ExperimentService(this._firestore);

  final FirebaseFirestore _firestore;

  FeatureFlagConfiguration _configuration = FeatureFlagConfiguration.empty();
  ReleaseEnvironment _environment = ReleaseEnvironment.production;
  String _releaseChannel = FeatureFlagConfiguration.defaultReleaseChannel;
  String? _tenantId;
  String? _storeId;
  String? _terminalId;

  final Map<String, String> _assignments = {};
  final Map<String, bool> _exposureLogged = {};

  FeatureFlagConfiguration get configuration => _configuration;
  ReleaseEnvironment get environment => _environment;
  String get releaseChannel => _releaseChannel;
  String? get tenantId => _tenantId;
  String? get storeId => _storeId;
  String? get terminalId => _terminalId;

  Iterable<ExperimentDefinition> get activeExperiments =>
      _configuration.eligibleExperiments(
        environment: _environment,
        releaseChannel: _releaseChannel,
      );

  void updateConfiguration(FeatureFlagConfiguration configuration) {
    _configuration = configuration;
    _pruneAssignments();
    notifyListeners();
  }

  void updateEnvironment(
    ReleaseEnvironment environment,
    String releaseChannel,
  ) {
    if (_environment == environment && _releaseChannel == releaseChannel) {
      return;
    }
    _environment = environment;
    _releaseChannel = releaseChannel;
    _pruneAssignments();
    notifyListeners();
  }

  void updateContext({
    String? tenantId,
    String? storeId,
    String? terminalId,
  }) {
    final previousSubject = _subjectKey;
    bool changed = false;
    if (_tenantId != tenantId) {
      _tenantId = tenantId;
      changed = true;
    }
    if (_storeId != storeId) {
      _storeId = storeId;
      changed = true;
    }
    if (_terminalId != terminalId) {
      _terminalId = terminalId;
      changed = true;
    }
    if (changed && previousSubject != _subjectKey) {
      _assignments.clear();
      _exposureLogged.clear();
    }
    if (changed) {
      notifyListeners();
    }
  }

  String? getVariant(
    String experimentId, {
    String? subjectId,
    bool logExposure = true,
  }) {
    final experiment = _configuration.resolveExperiment(
      experimentId,
      environment: _environment,
      releaseChannel: _releaseChannel,
    );
    if (experiment == null) {
      _assignments.remove(experimentId);
      _exposureLogged.remove(experimentId);
      return null;
    }

    final subjectKey = subjectId ?? _subjectKey;
    if (subjectKey.isEmpty) {
      return null;
    }

    if (!experiment.isSubjectEligible(subjectKey)) {
      _assignments[experimentId] = experiment.defaultVariant;
      return experiment.defaultVariant;
    }

    final variant = experiment.assignVariant(subjectKey);
    _assignments[experimentId] = variant;

    if (logExposure && !(_exposureLogged[experimentId] ?? false)) {
      _exposureLogged[experimentId] = true;
      unawaited(
        logExposureEvent(
          experimentId,
          variant: variant,
          subjectKey: subjectKey,
        ),
      );
    }

    return variant;
  }

  String? getAssignedVariant(String experimentId) =>
      _assignments[experimentId];

  Future<void> logExposureEvent(
    String experimentId, {
    String? variant,
    String? subjectKey,
    Map<String, dynamic>? metadata,
  }) async {
    final resolvedVariant = variant ?? _assignments[experimentId];
    if (resolvedVariant == null) {
      return;
    }
    final payload = _buildEventPayload(
      experimentId,
      resolvedVariant,
      'exposure',
      subjectKey: subjectKey,
      metadata: metadata,
    );
    await _firestore.collection('experimentEvents').add(payload);
  }

  Future<void> logConversion(
    String experimentId, {
    String? variant,
    String? subjectKey,
    String conversion = 'conversion',
    Map<String, dynamic>? metadata,
  }) async {
    final resolvedVariant = variant ?? _assignments[experimentId];
    if (resolvedVariant == null) {
      return;
    }
    final payload = _buildEventPayload(
      experimentId,
      resolvedVariant,
      conversion,
      subjectKey: subjectKey,
      metadata: metadata,
    );
    await _firestore.collection('experimentEvents').add(payload);
  }

  Map<String, dynamic> _buildEventPayload(
    String experimentId,
    String variant,
    String eventType, {
    String? subjectKey,
    Map<String, dynamic>? metadata,
  }) {
    return {
      'experimentId': experimentId,
      'variant': variant,
      'event': eventType,
      'timestamp': Timestamp.now(),
      'environment': _environment.wireName,
      'releaseChannel': _releaseChannel,
      if (_tenantId != null) 'tenantId': _tenantId,
      if (_storeId != null) 'storeId': _storeId,
      if (_terminalId != null) 'terminalId': _terminalId,
      if (subjectKey != null) 'subject': subjectKey,
      if (metadata != null && metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  void _pruneAssignments() {
    final activeIds = activeExperiments.map((e) => e.id).toSet();
    _assignments.removeWhere((key, value) => !activeIds.contains(key));
    _exposureLogged.removeWhere((key, value) => !activeIds.contains(key));
  }

  String get _subjectKey =>
      _terminalId ?? _storeId ?? _tenantId ?? '';
}
