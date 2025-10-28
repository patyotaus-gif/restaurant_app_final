import 'package:collection/collection.dart';
/// Defines the granular permissions used throughout the back office.
enum Permission {
  viewInventory,
  adjustInventory,
  managePurchaseOrders,
  manageStores,
  manageEmployees,
  manageRoles,
  processSales,
  viewAuditLogs,
}

/// Utility registry that centralizes role to permission mapping.
///
/// The data is intentionally declared as a [Map] so it can easily be merged
/// with dynamic role definitions loaded from Firestore in the future.
class RolePermissionRegistry {
  static final Map<String, Set<Permission>> _defaultRolePermissions = {
    'owner': Permission.values.toSet(),
    'manager': {
      Permission.viewInventory,
      Permission.adjustInventory,
      Permission.managePurchaseOrders,
      Permission.processSales,
      Permission.manageEmployees,
      Permission.viewAuditLogs,
    },
    'supervisor': {
      Permission.viewInventory,
      Permission.adjustInventory,
      Permission.managePurchaseOrders,
      Permission.processSales,
    },
    'stock_controller': {
      Permission.viewInventory,
      Permission.adjustInventory,
      Permission.managePurchaseOrders,
    },
    'cashier': {Permission.processSales},
    'viewer': {Permission.viewInventory},
  };

  static Map<String, Set<Permission>> _customOverrides = {};

  static void registerCustomRoles(Map<String, Set<Permission>> roles) {
    if (roles.isEmpty) return;
    _customOverrides = Map<String, Set<Permission>>.from(roles);
  }

  static Set<Permission> permissionsForRole(String? roleName) {
    if (roleName == null || roleName.isEmpty) {
      return const {};
    }
    final normalized = roleName.toLowerCase();
    if (_customOverrides.containsKey(normalized)) {
      return _customOverrides[normalized]!;
    }
    return _defaultRolePermissions[normalized] ?? const {};
  }

  static bool hasPermission(String? roleName, Permission permission) {
    return permissionsForRole(roleName).contains(permission);
  }

  /// Utility helper primarily used inside tests so we can confirm overrides
  /// behave as expected without leaking state between runs.
  static void resetToDefaults() {
    if (_customOverrides.isEmpty) return;
    _customOverrides = {};
  }

  static Map<String, Set<Permission>> snapshot() {
    if (_customOverrides.isEmpty) {
      return Map.unmodifiable(_defaultRolePermissions);
    }
    final combined = Map<String, Set<Permission>>.from(_defaultRolePermissions);
    combined.addAll(_customOverrides);
    return Map.unmodifiable(combined);
  }
}
