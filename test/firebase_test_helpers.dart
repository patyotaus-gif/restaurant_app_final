// test/firebase_test_helpers.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';

const MethodChannel _firebaseCoreChannel = MethodChannel(
  'plugins.flutter.io/firebase_core',
);

const Map<String, dynamic> _defaultFirebaseOptions = <String, dynamic>{
  'apiKey': 'test-api-key',
  'appId': '1:1234567890:android:abc123',
  'messagingSenderId': '1234567890',
  'projectId': 'test-project-id',
};

Future<void> setupFirebaseCoreMocks() async {
  _firebaseCoreChannel.setMockMethodCallHandler((MethodCall call) async {
    switch (call.method) {
      case 'Firebase#initializeCore':
        return <String, dynamic>{
          'name': '[DEFAULT]',
          'options': Map<String, dynamic>.from(_defaultFirebaseOptions),
          'isAutomaticDataCollectionEnabled': true,
          'pluginConstants': <String, dynamic>{},
        };
      case 'Firebase#initializeApp':
        final Map<String, dynamic> arguments = Map<String, dynamic>.from(
          call.arguments as Map<dynamic, dynamic>,
        );
        return <String, dynamic>{
          'name': arguments['appName'] as String,
          'options': Map<String, dynamic>.from(
            arguments['options'] as Map<dynamic, dynamic>,
          ),
          'isAutomaticDataCollectionEnabled': true,
        };
      case 'Firebase#appNamed':
        return <String, dynamic>{
          'name': call.arguments['appName'] as String,
          'options': Map<String, dynamic>.from(_defaultFirebaseOptions),
          'isAutomaticDataCollectionEnabled': true,
        };
      case 'Firebase#allApps':
        return <Map<String, dynamic>>[
          <String, dynamic>{
            'name': '[DEFAULT]',
            'options': Map<String, dynamic>.from(_defaultFirebaseOptions),
            'isAutomaticDataCollectionEnabled': true,
          },
        ];
      default:
        return null;
    }
  });
}

// A mock for Firebase.initializeApp
Future<void> setupMockFirebaseApp() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await setupFirebaseCoreMocks();
  await Firebase.initializeApp();
}

class MockFirebaseApp extends Mock implements FirebaseApp {
  @override
  String get name => '[DEFAULT]';
}
