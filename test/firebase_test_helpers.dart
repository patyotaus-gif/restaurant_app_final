import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_core_platform_interface/firebase_core_platform_interface.dart';

typedef Callback = void Function(MethodCall call);

void setupFirebaseAuthMocks([Callback? customHandlers]) {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel firebaseCoreChannel = MethodChannel(
    'plugins.flutter.io/firebase_core',
  );

  firebaseCoreChannel.setMockMethodCallHandler((call) async {
    if (call.method == 'Firebase#initialize') {
      return {
        'name': '[DEFAULT]',
        'options': {
          'apiKey': '123',
          'appId': '123',
          'messagingSenderId': '123',
          'projectId': '123',
        },
        'pluginConstants': {},
      };
    }

    if (customHandlers != null) {
      customHandlers(call);
    }

    return null;
  });
}

class MockFirebaseApp extends Mock implements FirebaseApp {}
