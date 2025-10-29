// test/firebase_test_helpers.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

// A mock for Firebase.initializeApp
Future<void> setupMockFirebaseApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final original = Firebase.app;
  final mockApp = MockFirebaseApp();

  // Replace the default Firebase app with a mock
  TestFirebaseCoreHostApi.setup(
    app: mockApp,
    apps: [mockApp],
  );
}

class MockFirebaseApp extends Mock implements FirebaseApp {
  @override
  String get name => '[DEFAULT]';
}
