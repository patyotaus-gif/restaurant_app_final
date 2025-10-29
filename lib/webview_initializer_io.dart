// lib/webview_initializer_io.dart

import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform;

Future<void> performWebviewInitialization() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    // No explicit initialization is needed for webview_windows
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    // No explicit initialization is needed for wkwebview
  }
}
