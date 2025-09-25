// lib/qr_generator_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
class QrGeneratorPage extends StatefulWidget {
  const QrGeneratorPage({super.key});

  @override
  State<QrGeneratorPage> createState() => _QrGeneratorPageState();
}

class _QrGeneratorPageState extends State<QrGeneratorPage> {
  final _tableNumberController = TextEditingController();
  String? _qrData;

  // URL หลักของเว็บแอปคุณ (จาก Firebase Hosting)
  final String _baseUrl = "https://fluke-qr01.web.app";

  void _generateQrCode() {
    if (_tableNumberController.text.isNotEmpty) {
      setState(() {
        _qrData = "$_baseUrl/table/${_tableNumberController.text}";
      });
    }
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generate QR Code for Table')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _tableNumberController,
              decoration: const InputDecoration(
                labelText: 'Enter Table Number',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _generateQrCode,
              child: const Text('Generate'),
            ),
            const SizedBox(height: 30),
            if (_qrData != null)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'QR Code for: $_qrData',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 20),
                      QrImageView(
                        data: _qrData!,
                        version: QrVersions.auto,
                        size: 250.0,
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
