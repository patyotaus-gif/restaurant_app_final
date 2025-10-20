// lib/barcode_scanner_page.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  MobileScannerController? _scannerController;
  bool _isScanCompleted = false;

  bool get _isMobileScannerSupported {
    if (kIsWeb) return false;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
        return true;
      default:
        return false;
    }
  }

  @override
  void initState() {
    super.initState();
    if (_isMobileScannerSupported) {
      _scannerController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _scannerController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isMobileScannerSupported) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Scan Barcode'),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Barcode scanning is only available on Android and iOS devices.',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController?.toggleTorch(),
          ),
        ],
      ),
      body: MobileScanner(
        controller: _scannerController,
        onDetect: (capture) {
          if (!_isScanCompleted) {
            setState(() {
              _isScanCompleted = true;
            });
            final String? code = capture.barcodes.first.rawValue;
            if (code != null) {
              // Return the scanned code to the previous page
              Navigator.of(context).pop(code);
            }
          }
        },
      ),
    );
  }
}
