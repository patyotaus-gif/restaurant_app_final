import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Mocks
class MockFirebasePlatform extends Mock implements FirebasePlatform {}

class MockFirebaseApp extends Mock implements FirebaseApp {}

// Matchers
class MockFirebaseOptions extends Mock implements FirebaseOptions {}

Future<void> setupMockFirebaseApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  final mockCore = MockFirebasePlatform();
  Firebase.delegatePackingProperty = mockCore;
  when(
    () => mockCore.initializeApp(
      name: any(named: 'name'),
      options: any(named: 'options'),
    ),
  ).thenAnswer((_) async => mockCore); // Return the mockCore itself
  when(() => mockCore.app(any())).thenReturn(MockFirebaseApp());
  // Mock the .options getter
  when(() => mockCore.options).thenReturn(MockFirebaseOptions());
}
