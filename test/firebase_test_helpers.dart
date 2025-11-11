import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockFirebasePlatform extends Mock implements FirebasePlatform {
  @override
  FirebaseApp app([String name = Firebase.appCheck().app.name]) {
    return MockFirebaseApp();
  }

  @override
  Future<FirebaseApp> initializeApp({
    String? name,
    FirebaseOptions? options,
  }) async {
    return MockFirebaseApp();
  }
}

class MockFirebaseApp extends Mock implements FirebaseApp {}

// Matchers
class MockFirebaseOptions extends Mock implements FirebaseOptions {}

Future<void> setupMockFirebaseApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockCore = MockFirebasePlatform();
  Firebase.delegatePackingProperty = mockCore;
}
