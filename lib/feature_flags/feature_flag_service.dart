import 'package:cloud_firestore/cloud_firestore.dart';

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
  }) async {
    final docRef = _firestore.collection('featureFlags').doc(tenantId);
    final updates = <String, dynamic>{};
    switch (scope) {
      case FeatureFlagScope.tenant:
        updates['flags.$flag'] = isEnabled;
        break;
      case FeatureFlagScope.store:
        if (storeId == null || storeId.isEmpty) {
          throw ArgumentError(
            'storeId is required for store-scoped feature flags.',
          );
        }
        updates['stores.$storeId.$flag'] = isEnabled;
        break;
      case FeatureFlagScope.terminal:
        if (terminalId == null || terminalId.isEmpty) {
          throw ArgumentError(
            'terminalId is required for terminal-scoped feature flags.',
          );
        }
        updates['terminals.$terminalId.$flag'] = isEnabled;
        break;
    }
    await docRef.set(updates, SetOptions(merge: true));
  }
}
