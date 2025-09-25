// lib/barcode_scanner_page.dart

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
class BarcodeScannerPage extends StatefulWidget {
  const BarcodeScannerPage({super.key});

  @override
  State<BarcodeScannerPage> createState() => _BarcodeScannerPageState();
}

class _BarcodeScannerPageState extends State<BarcodeScannerPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isScanCompleted = false;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Barcode'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on),
            onPressed: () => _scannerController.toggleTorch(),
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
