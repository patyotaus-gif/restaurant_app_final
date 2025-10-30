// test/firebase_test_helpers.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const MethodChannel _firebaseCoreMethodChannel = MethodChannel(
  'plugins.flutter.io/firebase_core',
);

const Map<String, Object?> _defaultFirebaseOptions = <String, Object?>{
  'apiKey': 'test-api-key',
  'appId': '1:1234567890:android:abcdef123456',
  'messagingSenderId': '1234567890',
  'projectId': 'test-project',
};

Future<void> setupFirebaseCoreMocks() async {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_firebaseCoreMethodChannel, (
        MethodCall methodCall,
      ) async {
        switch (methodCall.method) {
          case 'Firebase#initializeCore':
            return <Map<String, dynamic>>[
              <String, dynamic>{
                'name': '[DEFAULT]',
                'options': _defaultFirebaseOptions,
                'pluginConstants': <String, dynamic>{},
              },
            ];
          case 'Firebase#initializeApp':
            final Map<dynamic, dynamic> arguments =
                methodCall.arguments as Map<dynamic, dynamic>;
            return <String, dynamic>{
              'name': arguments['appName'],
              'options': arguments['options'] ?? _defaultFirebaseOptions,
              'pluginConstants': <String, dynamic>{},
            };
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
