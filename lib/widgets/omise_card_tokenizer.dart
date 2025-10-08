import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Result from Omise.js tokenization containing the generated token and
/// non-sensitive card details that Omise exposes.
class OmiseCardTokenizationResult {
  const OmiseCardTokenizationResult({
    required this.token,
    this.card,
  });

  /// Omise token identifier (e.g. tokn_...).
  final String token;

  /// Additional non-sensitive information returned by Omise about the card.
  final Map<String, dynamic>? card;
}

/// Helper that displays a secure Omise.js powered WebView to tokenize card data
/// without the Flutter app ever handling primary account numbers directly.
class OmiseCardTokenizer {
  static Future<OmiseCardTokenizationResult?> collectToken({
    required BuildContext context,
    required String publicKey,
    double? amount,
    String currency = 'THB',
  }) {
    return Navigator.of(context).push<OmiseCardTokenizationResult>(
      MaterialPageRoute<OmiseCardTokenizationResult>(
        fullscreenDialog: true,
        builder: (_) => _OmiseCardTokenizationPage(
          publicKey: publicKey,
          amount: amount,
          currency: currency,
        ),
      ),
    );
  }
}

class _OmiseCardTokenizationPage extends StatefulWidget {
  const _OmiseCardTokenizationPage({
    required this.publicKey,
    this.amount,
    this.currency = 'THB',
  });

  final String publicKey;
  final double? amount;
  final String currency;

  @override
  State<_OmiseCardTokenizationPage> createState() =>
      _OmiseCardTokenizationPageState();
}

class _OmiseCardTokenizationPageState
    extends State<_OmiseCardTokenizationPage> {
  late final WebViewController _controller;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'OmiseBridge',
        onMessageReceived: _handleBridgeMessage,
      )
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
        ),
      )
      ..loadHtmlString(_buildHostedFormHtml());
  }

  void _handleBridgeMessage(JavaScriptMessage message) {
    try {
      final dynamic decoded = jsonDecode(message.message);
      if (decoded is! Map<String, dynamic>) {
        return;
      }
      final type = decoded['type'] as String?;
      switch (type) {
        case 'success':
          final token = decoded['token'] as String?;
          if (token == null || token.isEmpty) {
            return;
          }
          final card = decoded['card'];
          Navigator.of(context).pop(
            OmiseCardTokenizationResult(
              token: token,
              card: card is Map
                  ? Map<String, dynamic>.from(card as Map)
                  : null,
            ),
          );
          break;
        case 'error':
          final message = decoded['message'] as String?;
          if (mounted) {
            setState(() {
              _errorMessage = message ?? 'Tokenization failed. Please try again.';
            });
          }
          break;
        default:
          break;
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Unable to parse response from tokenization form.';
        });
      }
    }
  }

  String _buildHostedFormHtml() {
    final buffer = StringBuffer();
    final localeCurrency = jsonEncode(widget.currency);
    final localeAmount = widget.amount != null
        ? jsonEncode(widget.amount!.toStringAsFixed(2))
        : 'null';

    buffer
      ..writeln('<!DOCTYPE html>')
      ..writeln('<html lang="th">')
      ..writeln('<head>')
      ..writeln('  <meta charset="utf-8" />')
      ..writeln('  <meta name="viewport" content="width=device-width, initial-scale=1" />')
      ..writeln('  <title>Secure Card Entry</title>')
      ..writeln('  <style>')
      ..writeln('    :root { color-scheme: light dark; font-family: "Sarabun", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }')
      ..writeln('    body { margin: 0; padding: 16px; background: #f4f5f7; color: #1f2933; }')
      ..writeln('    .container { max-width: 420px; margin: 0 auto; background: #ffffff; border-radius: 16px; padding: 24px; box-shadow: 0 12px 36px rgba(15, 23, 42, 0.12); }')
      ..writeln('    h1 { font-size: 20px; margin-bottom: 12px; text-align: center; }')
      ..writeln('    p.helper { font-size: 14px; margin-top: 0; margin-bottom: 16px; text-align: center; color: #52606d; }')
      ..writeln('    form { display: grid; gap: 12px; }')
      ..writeln('    label { font-weight: 600; font-size: 13px; color: #334155; }')
      ..writeln('    input { width: 100%; padding: 12px 14px; font-size: 16px; border: 1px solid #cbd5e1; border-radius: 10px; transition: border-color 0.2s ease, box-shadow 0.2s ease; }')
      ..writeln('    input:focus { outline: none; border-color: #2563eb; box-shadow: 0 0 0 3px rgba(37, 99, 235, 0.2); }')
      ..writeln('    .row { display: grid; gap: 12px; grid-template-columns: repeat(2, minmax(0, 1fr)); }')
      ..writeln('    button { margin-top: 8px; padding: 14px 18px; border: none; border-radius: 12px; font-size: 16px; font-weight: 600; background: linear-gradient(135deg, #2563eb, #7c3aed); color: #ffffff; cursor: pointer; box-shadow: 0 10px 25px rgba(37, 99, 235, 0.35); transition: transform 0.2s ease, box-shadow 0.2s ease; }')
      ..writeln('    button:hover { transform: translateY(-1px); box-shadow: 0 16px 30px rgba(124, 58, 237, 0.35); }')
      ..writeln('    button:disabled, form.submitting button { opacity: 0.6; cursor: not-allowed; box-shadow: none; }')
      ..writeln('    .error { margin-top: 12px; padding: 12px; border-radius: 10px; background: rgba(220, 38, 38, 0.08); color: #b91c1c; font-size: 14px; display: none; }')
      ..writeln('    .error.active { display: block; }')
      ..writeln('    .badge { display: inline-flex; align-items: center; gap: 6px; background: rgba(16, 185, 129, 0.12); color: #047857; padding: 6px 10px; border-radius: 999px; font-size: 12px; font-weight: 600; margin: 0 auto 12px; }')
      ..writeln('    @media (max-width: 480px) { body { padding: 12px; } .container { padding: 20px; } }')
      ..writeln('  </style>')
      ..writeln('  <script src="https://cdn.omise.co/omise.js"></script>')
      ..writeln('  <script>')
      ..writeln('    const PUBLIC_KEY = ${jsonEncode(widget.publicKey)};')
      ..writeln('    const DISPLAY_AMOUNT = $localeAmount;')
      ..writeln('    const DISPLAY_CURRENCY = $localeCurrency;')
      ..writeln('    function emitMessage(payload) {')
      ..writeln('      if (window.OmiseBridge && window.OmiseBridge.postMessage) {')
      ..writeln('        window.OmiseBridge.postMessage(JSON.stringify(payload));')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    function setError(message) {')
      ..writeln('      const el = document.getElementById("error-message");')
      ..writeln('      if (!el) return;')
      ..writeln('      if (message) {')
      ..writeln('        el.textContent = message;')
      ..writeln('        el.classList.add("active");')
      ..writeln('      } else {')
      ..writeln('        el.textContent = "";')
      ..writeln('        el.classList.remove("active");')
      ..writeln('      }')
      ..writeln('    }')
      ..writeln('    function formatCardNumber(value) {')
      ..writeln('      return value.replace(/[^0-9]/g, "").replace(/(.{4})/g, "$1 ").trim();')
      ..writeln('    }')
      ..writeln('    document.addEventListener("DOMContentLoaded", () => {')
      ..writeln('      if (!PUBLIC_KEY) {')
      ..writeln('        setError("Missing Omise public key");')
      ..writeln('        emitMessage({ type: "error", message: "Missing Omise public key" });')
      ..writeln('        return;')
      ..writeln('      }')
      ..writeln('      Omise.setPublicKey(PUBLIC_KEY);')
      ..writeln('      const form = document.getElementById("card-form");')
      ..writeln('      const numberInput = document.getElementById("card-number");')
      ..writeln('      numberInput.addEventListener("input", (event) => {')
      ..writeln('        const position = event.target.selectionStart;')
      ..writeln('        event.target.value = formatCardNumber(event.target.value);')
      ..writeln('        event.target.selectionStart = event.target.selectionEnd = position;')
      ..writeln('      });')
      ..writeln('      document.querySelectorAll("input[maxlength]").forEach((input) => {')
      ..writeln('        input.addEventListener("input", (event) => {')
      ..writeln('          const max = parseInt(event.target.getAttribute("maxlength"), 10);')
      ..writeln('          if (event.target.value.length > max) {')
      ..writeln('            event.target.value = event.target.value.slice(0, max);')
      ..writeln('          }')
      ..writeln('        });')
      ..writeln('      });')
      ..writeln('      form.addEventListener("submit", (event) => {')
      ..writeln('        event.preventDefault();')
      ..writeln('        form.classList.add("submitting");')
      ..writeln('        setError("");')
      ..writeln('        const card = {')
      ..writeln('          name: document.getElementById("card-name").value.trim(),')
      ..writeln('          number: document.getElementById("card-number").value.replace(/\s+/g, ""),')
      ..writeln('          expiration_month: document.getElementById("card-exp-month").value.trim(),')
      ..writeln('          expiration_year: document.getElementById("card-exp-year").value.trim(),')
      ..writeln('          security_code: document.getElementById("card-cvc").value.trim(),')
      ..writeln('        };')
      ..writeln('        if (!card.name || !card.number || !card.expiration_month || !card.expiration_year || !card.security_code) {')
      ..writeln('          setError("กรุณากรอกข้อมูลบัตรให้ครบถ้วน");')
      ..writeln('          form.classList.remove("submitting");')
      ..writeln('          return;')
      ..writeln('        }')
      ..writeln('        Omise.createToken("card", card, (statusCode, response) => {')
      ..writeln('          form.classList.remove("submitting");')
      ..writeln('          if (statusCode === 200 && response && response.id) {')
      ..writeln('            emitMessage({ type: "success", token: response.id, card: response.card });')
      ..writeln('          } else {')
      ..writeln('            const message = (response && response.message) || "ไม่สามารถสร้างโทเค็นของบัตรได้";')
      ..writeln('            setError(message);')
      ..writeln('            emitMessage({ type: "error", message });')
      ..writeln('          }')
      ..writeln('        });')
      ..writeln('      });')
      ..writeln('      const amountLabel = document.getElementById("amount-label");')
      ..writeln('      if (DISPLAY_AMOUNT && amountLabel) {')
      ..writeln('        amountLabel.textContent = `ยอดเรียกเก็บ ${DISPLAY_CURRENCY} ${DISPLAY_AMOUNT}`;')
      ..writeln('        amountLabel.style.display = "block";')
      ..writeln('      }');
    buffer
      ..writeln('    });')
      ..writeln('  </script>')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('  <div class="container" role="form">')
      ..writeln('    <span class="badge">Omise.js • Secure Form</span>')
      ..writeln('    <h1>กรอกข้อมูลบัตร</h1>')
      ..writeln('    <p id="amount-label" class="helper" style="display:none"></p>')
      ..writeln('    <p class="helper">ข้อมูลบัตรจะถูกเข้ารหัสและส่งตรงไปยัง Omise เพื่อสร้างโทเค็นที่ปลอดภัย</p>')
      ..writeln('    <form id="card-form" novalidate>')
      ..writeln('      <div>')
      ..writeln('        <label for="card-name">ชื่อบนบัตร</label>')
      ..writeln('        <input id="card-name" type="text" autocomplete="cc-name" placeholder="ชื่อ-นามสกุล" required />')
      ..writeln('      </div>')
      ..writeln('      <div>')
      ..writeln('        <label for="card-number">หมายเลขบัตร</label>')
      ..writeln('        <input id="card-number" type="tel" inputmode="numeric" autocomplete="cc-number" placeholder="0000 0000 0000 0000" maxlength="23" required />')
      ..writeln('      </div>')
      ..writeln('      <div class="row">')
      ..writeln('        <div>')
      ..writeln('          <label for="card-exp-month">เดือนหมดอายุ (MM)</label>')
      ..writeln('          <input id="card-exp-month" type="tel" inputmode="numeric" autocomplete="cc-exp-month" placeholder="08" maxlength="2" required />')
      ..writeln('        </div>')
      ..writeln('        <div>')
      ..writeln('          <label for="card-exp-year">ปีหมดอายุ (YYYY)</label>')
      ..writeln('          <input id="card-exp-year" type="tel" inputmode="numeric" autocomplete="cc-exp-year" placeholder="2027" maxlength="4" required />')
      ..writeln('        </div>')
      ..writeln('      </div>')
      ..writeln('      <div>')
      ..writeln('        <label for="card-cvc">รหัสความปลอดภัย (CVV)</label>')
      ..writeln('        <input id="card-cvc" type="tel" inputmode="numeric" autocomplete="cc-csc" placeholder="123" maxlength="4" required />')
      ..writeln('      </div>')
      ..writeln('      <button type="submit">สร้างโทเค็นเพื่อชำระเงิน</button>')
      ..writeln('      <div id="error-message" class="error" role="alert" aria-live="polite"></div>')
      ..writeln('    </form>')
      ..writeln('  </div>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final amountText = widget.amount != null
        ? '${widget.currency} ${widget.amount!.toStringAsFixed(2)}'
        : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('ชำระด้วยบัตร'),
        actions: [
          IconButton(
            tooltip: 'ยกเลิก',
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      body: Column(
        children: [
          if (amountText != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.credit_card, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'ยอดที่ต้องชำระ $amountText',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              children: [
                WebViewWidget(controller: _controller),
                if (_isLoading)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x55FFFFFF),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Container(
              width: double.infinity,
              color: Theme.of(context).colorScheme.errorContainer,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(
                    Icons.error_outline,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _errorMessage = null;
                        _isLoading = true;
                      });
                      _controller.loadHtmlString(_buildHostedFormHtml());
                    },
                    child: const Text('ลองอีกครั้ง'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
