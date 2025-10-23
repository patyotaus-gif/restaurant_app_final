import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:restaurant_app_final/auth_service.dart';
import 'dart:convert';
import 'package:cryptography/cryptography.dart';

void main() {
  late AuthService authService;
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() async {
    fakeFirestore = FakeFirebaseFirestore();
    authService = AuthService(firestore: fakeFirestore);

    // Add a mock employee with a hashed PIN to the fake Firestore
    final algorithm = Sha256();
    final hashedPinBytes = await algorithm.hash(utf8.encode('1234'));
    final hashedPin = base64Url.encode(hashedPinBytes.bytes);

    await fakeFirestore.collection('employees').add({
      'name': 'Test Employee',
      'hashedPin': hashedPin,
      'storeIds': ['store1'],
      'role': 'employee',
      'isSuperAdmin': false,
      'roleByStore': {'store1': 'employee'},
    });
  });

  test('loginWithPin should return true for correct PIN', () async {
    final result = await authService.loginWithPin('1234');
    expect(result, isTrue);
    expect(authService.isLoggedIn, isTrue);
    expect(authService.loggedInEmployee?.name, 'Test Employee');
  });

  test('loginWithPin should return false for incorrect PIN', () async {
    final result = await authService.loginWithPin('5678');
    expect(result, isFalse);
    expect(authService.isLoggedIn, isFalse);
  });
}
