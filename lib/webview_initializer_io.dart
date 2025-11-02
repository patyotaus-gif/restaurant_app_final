import 'package:flutter/foundation.dart' show defaultTargetPlatform, TargetPlatform, debugPrint;
import 'package:webview_windows/webview_windows.dart';

Future<void> performWebviewInitialization() async {
  if (defaultTargetPlatform == TargetPlatform.windows) {
    try {
      final String? webviewVersion = await getWebViewVersion();
      if (webviewVersion == null) {
        debugPrint('WebView2 Runtime is not installed.');
        return;
      }
      await WebviewWindow.initialize();
    } catch (e) {
      debugPrint('Failed to initialize webview_windows: $e');
    }
  } else if (defaultTargetPlatform == TargetPlatform.macOS) {
    // No explicit initialization is needed for wkwebview
  }
}
