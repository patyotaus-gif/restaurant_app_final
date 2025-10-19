import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Helper that presents a WebView or deep link to complete payment
/// authorizations such as 3-D Secure or mobile banking flows.
class PaymentRedirectLauncher {
  const PaymentRedirectLauncher._();

  /// Opens a new page that navigates to [url] so the user can
  /// complete an external payment step. If the URL uses a non-http(s)
  /// scheme, the method attempts to launch it externally instead of
  /// displaying a WebView.
  static Future<bool> open({
    required BuildContext context,
    required Uri url,
    String? title,
    String? description,
  }) async {
    if (!context.mounted) {
      return false;
    }

    if (!_isHttpScheme(url)) {
      return _launchExternal(context, url);
    }

    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (_) => _PaymentRedirectPage(
          initialUrl: url,
          title: title,
          description: description,
        ),
      ),
    );

    return result ?? true;
  }

  static bool _isHttpScheme(Uri uri) {
    final scheme = uri.scheme.toLowerCase();
    return scheme == 'http' || scheme == 'https';
  }

  static Future<bool> _launchExternal(BuildContext context, Uri uri) async {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปิดลิงก์ ${uri.toString()} ได้'),
          ),
        );
      }
      return launched;
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('เกิดข้อผิดพลาดในการเปิดลิงก์: $error'),
          ),
        );
      }
      return false;
    }
  }
}

class _PaymentRedirectPage extends StatefulWidget {
  const _PaymentRedirectPage({
    required this.initialUrl,
    this.title,
    this.description,
  });

  final Uri initialUrl;
  final String? title;
  final String? description;

  @override
  State<_PaymentRedirectPage> createState() => _PaymentRedirectPageState();
}

class _PaymentRedirectPageState extends State<_PaymentRedirectPage> {
  WebViewController? _controller;
  bool _isLoading = true;
  String? _errorMessage;
  Object? _initializationError;

  @override
  void initState() {
    super.initState();
    try {
      final controller = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..setBackgroundColor(Colors.transparent)
        ..setNavigationDelegate(
          NavigationDelegate(
            onPageStarted: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = true;
                  _errorMessage = null;
                });
              }
            },
            onPageFinished: (_) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                });
              }
            },
            onWebResourceError: (error) {
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage = error.description;
                });
              }
            },
            onNavigationRequest: (request) {
              final uri = Uri.tryParse(request.url);
              if (uri != null &&
                  !PaymentRedirectLauncher._isHttpScheme(uri)) {
                // Launch non-http(s) URLs using the platform handler to support
                // app redirects (e.g. SCB Easy deep links).
                unawaited(
                  PaymentRedirectLauncher._launchExternal(context, uri),
                );
                return NavigationDecision.prevent;
              }
              return NavigationDecision.navigate;
            },
          ),
        )
        ..loadRequest(widget.initialUrl);
      _controller = controller;
    } catch (error, stackTrace) {
      debugPrint('Failed to initialize payment redirect WebView: $error');
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'payment_redirect_page',
          context: ErrorDescription('initializing payment redirect WebView'),
        ),
      );
      if (!mounted) {
        _initializationError = error;
        _isLoading = false;
        return;
      }
      setState(() {
        _initializationError = error;
        _isLoading = false;
        _errorMessage = null;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(
          PaymentRedirectLauncher._launchExternal(
            context,
            widget.initialUrl,
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.title ?? 'ดำเนินการชำระเงิน';
    final controller = _controller;

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(true),
            icon: const Icon(Icons.close),
            tooltip: 'ปิด',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.description != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  widget.description!,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            Expanded(
              child: controller == null
                  ? _WebViewUnavailableMessage(
                      initialUrl: widget.initialUrl,
                      initializationError: _initializationError,
                    )
                  : Stack(
                      children: [
                        Positioned.fill(
                          child: WebViewWidget(controller: controller),
                        ),
                        if (_isLoading)
                          const Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_errorMessage != null)
                          Positioned.fill(
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 40,
                                      color: Colors.redAccent,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'ไม่สามารถโหลดหน้าชำระเงินได้',
                                      style: theme.textTheme.titleMedium,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      _errorMessage!,
                                      style: theme.textTheme.bodySmall,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    FilledButton.icon(
                                      onPressed: () {
                                        setState(() {
                                          _errorMessage = null;
                                          _isLoading = true;
                                        });
                                        controller.loadRequest(
                                          widget.initialUrl,
                                        );
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('ลองใหม่อีกครั้ง'),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebViewUnavailableMessage extends StatelessWidget {
  const _WebViewUnavailableMessage({
    required this.initialUrl,
    this.initializationError,
  });

  final Uri initialUrl;
  final Object? initializationError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.open_in_new,
              size: 48,
              color: Colors.blueAccent,
            ),
            const SizedBox(height: 16),
            Text(
              'เปิดหน้ายืนยันการชำระเงินในเบราว์เซอร์ภายนอก',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'อุปกรณ์นี้ไม่รองรับการแสดงผลหน้าชำระเงินภายในแอปโดยตรง '
              'ระบบจะพยายามเปิดลิงก์ในแอปธนาคารหรือเบราว์เซอร์แทน.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            if (initializationError != null) ...[
              const SizedBox(height: 12),
              Text(
                'รายละเอียด: ${initializationError}',
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                unawaited(
                  PaymentRedirectLauncher._launchExternal(
                    context,
                    initialUrl,
                  ),
                );
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('เปิดลิงก์ในแอปธนาคาร/เบราว์เซอร์'),
            ),
          ],
        ),
      ),
    );
  }
}
