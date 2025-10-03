import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'feature_flag_configuration.dart';
import 'feature_flag_scope.dart';
class FeatureFlagService {
  FeatureFlagService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<FeatureFlagConfiguration> watchTenantFlags(String tenantId) {
    return _firestore
        .collection('featureFlags')
        .doc(tenantId)
        .snapshots()
        .map(
          (snapshot) =>
              FeatureFlagConfiguration.fromMap(snapshot.data() ?? const {}),
        );
  }

  Future<void> setFlag({
    required FeatureFlagScope scope,
    required String tenantId,
    required String flag,
    required bool isEnabled,
    String? storeId,
    String? terminalId,
    ReleaseEnvironment? environment,
    String? releaseChannel,
  }) async {
    final docRef = _firestore.collection('featureFlags').doc(tenantId);
    final updates = <String, dynamic>{};

    String scopedPath(String base) {
      switch (scope) {
        case FeatureFlagScope.tenant:
          return '$base.flags.$flag';
        case FeatureFlagScope.store:
          if (storeId == null || storeId.isEmpty) {
            throw ArgumentError(
              'storeId is required for store-scoped feature flags.',
            );
          }
          return '$base.stores.$storeId.$flag';
        case FeatureFlagScope.terminal:
          if (terminalId == null || terminalId.isEmpty) {
            throw ArgumentError(
              'terminalId is required for terminal-scoped feature flags.',
            );
          }
          return '$base.terminals.$terminalId.$flag';
      }
    }

    if (releaseChannel != null && releaseChannel.isNotEmpty) {
      if (scope != FeatureFlagScope.tenant) {
        throw ArgumentError(
          'Release channel overrides currently support tenant scope only.',
        );
      }
      final path = scopedPath('releaseChannels.$releaseChannel');
      updates[path] = isEnabled;
    } else if (environment != null) {
      final envKey = environment.wireName;
      final path = scopedPath('environments.$envKey');
      updates[path] = isEnabled;
    } else {
      final path = scopedPath('');
      updates[path] = isEnabled;
    }

    await docRef.set(updates, SetOptions(merge: true));
  }

  Future<void> configureReleaseChannel({
    required String tenantId,
    required String channel,
    ReleaseEnvironment? environment,
    Map<String, bool>? flagOverrides,
    Map<String, StagedRollout>? rollouts,
    bool clear = false,
  }) async {
    final docRef = _firestore.collection('featureFlags').doc(tenantId);

    if (clear) {
      await docRef.set(
        {
          'releaseChannels': {channel: FieldValue.delete()},
        },
        SetOptions(merge: true),
      );
      return;
    }

    final updates = <String, dynamic>{};

    if (environment != null) {
      updates['releaseChannels.$channel.environment'] = environment.wireName;
    }

    if (flagOverrides != null && flagOverrides.isNotEmpty) {
      flagOverrides.forEach((flag, value) {
        updates['releaseChannels.$channel.flags.$flag'] = value;
      });
    }

    if (rollouts != null && rollouts.isNotEmpty) {
      rollouts.forEach((flag, rollout) {
        updates['releaseChannels.$channel.rollouts.$flag'] = rollout.toMap();
      });
    }

    if (updates.isEmpty) {
      return;
    }

    await docRef.set(updates, SetOptions(merge: true));
  }
}
