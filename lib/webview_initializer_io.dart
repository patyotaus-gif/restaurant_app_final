import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:webview_windows/webview_windows.dart';

import 'main.dart';

Future<void> performWebviewInitialization() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    try {
      final webviewVersion = await getWebViewVersion();
      if (webviewVersion != null) {
        await WebviewWindow.initialize();
      }
    } catch (e) {
      debugPrint('Failed to initialize webview_windows: $e');
    }
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    // No explicit initialization is needed for wkwebview
  }
}
