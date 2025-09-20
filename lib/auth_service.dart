import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/employee_model.dart'; // <-- 1. Import Employee model
import 'models/role_permission_model.dart';

// Defines the available user roles
enum UserRole { owner, manager, employee, intern }

class AuthService with ChangeNotifier {
  Employee? _loggedInEmployee; // <-- 2. Store the full employee object
  String? _activeStoreId;

  Employee? get loggedInEmployee => _loggedInEmployee;
  String? get activeStoreId => _activeStoreId;
  List<String> get availableStoreIds => _loggedInEmployee?.storeIds ?? const [];
  String? get activeRoleName {
    if (_loggedInEmployee == null) {
      return null;
    }
    if (_loggedInEmployee!.isSuperAdmin) {
      return 'owner';
    }
    if (_activeStoreId != null &&
        _loggedInEmployee!.roleByStore.containsKey(_activeStoreId)) {
      return _loggedInEmployee!.roleByStore[_activeStoreId];
    }
    return _loggedInEmployee!.role;
  }

  UserRole? get currentRole {
    final roleName = activeRoleName;
    if (roleName == null) return null;
    try {
      return UserRole.values.firstWhere(
        (e) => e.toString() == 'UserRole.${roleName.toLowerCase()}',
      );
    } catch (_) {
      return null;
    }
  }

  bool get isLoggedIn => _loggedInEmployee != null;

  // Simple getters for easy checking
  bool get isOwner => currentRole == UserRole.owner;
  bool get isManager => currentRole == UserRole.manager;
  bool get isEmployee => currentRole == UserRole.employee;
  bool get isIntern => currentRole == UserRole.intern;

  Set<Permission> get currentPermissions {
    if (_loggedInEmployee?.isSuperAdmin == true) {
      return Permission.values.toSet();
    }
    return RolePermissionRegistry.permissionsForRole(activeRoleName);
  }

  bool hasPermission(Permission permission) {
    if (_loggedInEmployee?.isSuperAdmin == true) {
      return true;
    }
    return RolePermissionRegistry.hasPermission(activeRoleName, permission);
  }

  void setActiveStore(String? storeId) {
    if (_activeStoreId == storeId) return;
    _activeStoreId = storeId;
    notifyListeners();
  }

  // --- 3. NEW: Login method using PIN ---
  Future<bool> loginWithPin(String pin) async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('pin', isEqualTo: pin)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        _loggedInEmployee = Employee.fromFirestore(querySnapshot.docs.first);
        if (_loggedInEmployee!.storeIds.isNotEmpty) {
          _activeStoreId = _loggedInEmployee!.storeIds.first;
        }
        notifyListeners();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // --- 4. DEPRECATED: Old login method (we keep it for reference but won't use it) ---
  void login(UserRole role) {
    // This is no longer the primary way to log in.
    // Kept here in case you need a simple role-select for testing later.
  }

  Future<void> signOut() async {
    _loggedInEmployee = null;
    _activeStoreId = null;
    notifyListeners();
  }
}
