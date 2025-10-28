// lib/webview_initializer.dart

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;
import 'webview_initializer_stub.dart'
    if (dart.library.io) 'webview_initializer_io.dart';

Future<void> initializeWebview() async {
  if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.macOS) {
    await performWebviewInitialization();
  }
}
