import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:webview_windows/webview_windows.dart';

Future<void> performWebviewInitialization() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    try {
      await WebviewController.initializeEnvironment();
    } catch (e) {
      debugPrint('Failed to initialize webview_windows: $e');
      debugPrint('WebView2 Runtime may not be installed.');
    }
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    // No explicit initialization is needed for wkwebview
  }
}
