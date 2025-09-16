import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/employee_model.dart'; // <-- 1. Import Employee model

// Defines the available user roles
enum UserRole { owner, manager, employee, intern }

class AuthService with ChangeNotifier {
  Employee? _loggedInEmployee; // <-- 2. Store the full employee object

  Employee? get loggedInEmployee => _loggedInEmployee;
  UserRole? get currentRole => _loggedInEmployee?.role != null
      ? UserRole.values.firstWhere(
          (e) =>
              e.toString() ==
              'UserRole.${_loggedInEmployee!.role.toLowerCase()}',
        )
      : null;

  bool get isLoggedIn => _loggedInEmployee != null;

  // Simple getters for easy checking
  bool get isOwner => currentRole == UserRole.owner;
  bool get isManager => currentRole == UserRole.manager;
  bool get isEmployee => currentRole == UserRole.employee;
  bool get isIntern => currentRole == UserRole.intern;

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
    notifyListeners();
  }
}
