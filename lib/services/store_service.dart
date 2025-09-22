import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/employee_model.dart';
import '../models/role_permission_model.dart';
import '../models/store_model.dart';

class StoreService {
  StoreService(this._firestore);

  final FirebaseFirestore _firestore;

  Stream<List<Store>> watchStores({List<String>? storeIds}) {
    Query<Map<String, dynamic>> query = _firestore.collection('stores');
    if (storeIds != null && storeIds.isNotEmpty) {
      query = query.where(FieldPath.documentId, whereIn: storeIds);
    }
    query = query.where('isActive', isEqualTo: true);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Store.fromFirestore(doc))
          .toList(growable: false),
    );
  }

  Future<void> saveStore(Store store) async {
    final collection = _firestore.collection('stores');
    if (store.id.isEmpty) {
      await collection.add(store.toFirestore());
    } else {
      await collection
          .doc(store.id)
          .set(store.toFirestore(), SetOptions(merge: true));
    }
  }

  Future<void> setPluginOverrides(
    String storeId,
    Map<String, bool> pluginOverrides,
  ) async {
    await _firestore.collection('stores').doc(storeId).set({
      'pluginOverrides': pluginOverrides,
    }, SetOptions(merge: true));
  }

  Future<void> setPluginState({
    required String storeId,
    required String pluginId,
    required bool isEnabled,
  }) async {
    await _firestore.collection('stores').doc(storeId).set({
      'pluginOverrides': {pluginId: isEnabled},
    }, SetOptions(merge: true));
  }

  Future<void> assignEmployeeToStore({
    required Employee employee,
    required String storeId,
    required String roleName,
  }) async {
    final docRef = _firestore.collection('employees').doc(employee.id);
    final updatedStoreIds = Set<String>.from(employee.storeIds)..add(storeId);
    final updatedRoleByStore = Map<String, String>.from(employee.roleByStore)
      ..[storeId] = roleName;
    await docRef.update({
      'storeIds': updatedStoreIds.toList(),
      'roleByStore': updatedRoleByStore,
    });
  }

  Future<void> persistRoleOverrides(
    Map<String, Set<Permission>> rolePermissions,
  ) async {
    final batch = _firestore.batch();
    final collection = _firestore.collection('roleDefinitions');
    final snapshots = await collection.get();
    for (final doc in snapshots.docs) {
      batch.delete(doc.reference);
    }
    rolePermissions.forEach((role, permissions) {
      final docRef = collection.doc(role);
      batch.set(docRef, {
        'permissions': permissions.map((p) => p.name).toList(),
      });
    });
    await batch.commit();
  }

  Future<void> loadRoleOverrides() async {
    final snapshot = await _firestore.collection('roleDefinitions').get();
    final overrides = <String, Set<Permission>>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final permissions = (data['permissions'] as List<dynamic>? ?? [])
          .map(
            (value) => Permission.values.firstWhere(
              (p) => p.name == value,
              orElse: () => Permission.viewInventory,
            ),
          )
          .toSet();
      overrides[doc.id] = permissions;
    }
    RolePermissionRegistry.registerCustomRoles(overrides);
  }
}
