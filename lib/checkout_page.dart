// lib/checkout_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:go_router/go_router.dart';
import '../services/printing_service.dart';

class CheckoutPage extends StatefulWidget {
  final String orderId;
  final double totalAmount;
  final String orderIdentifier;

  const CheckoutPage({
    super.key,
    required this.orderId,
    required this.totalAmount,
    required this.orderIdentifier,
  });

  @override
  State<CheckoutPage> createState() => _CheckoutPageState();
}

class _CheckoutPageState extends State<CheckoutPage> {
  final _printingService = PrintingService();
  bool _isConfirming = false;

  @override
  void dispose() {
    super.dispose();
  }

  String _generatePromptPayPayload(double amount) {
    const yourPromptPayId = '0812345678';
    return 'promptpay-qr-code-payload-for-$yourPromptPayId-with-amount-$amount';
  }

  void _handleReceiptPreview() async {
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();
      if (!orderDoc.exists) {
        throw Exception('Order not found!');
      }
      await _printingService.previewReceipt(orderDoc.data()!);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Preview Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _confirmPayment() async {
    setState(() => _isConfirming = true);
    try {
      final orderRef = FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId);

      final orderDoc = await orderRef.get();
      final orderType = orderDoc.data()?['orderType'] ?? '';

      await orderRef.update({'status': 'completed'});

      if (context.mounted) {
        if (orderType == 'Retail') {
          context.go('/retail-pos');
        } else {
          context.go('/floorplan');
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update order: $e')));
      }
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _generatePromptPayPayload(widget.totalAmount);

    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout for ${widget.orderIdentifier}'),
        backgroundColor: Colors.green,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Scan to Pay',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 8,
                  child: QrImageView(
                    data: qrData,
                    version: QrVersions.auto,
                    size: 250.0,
                    backgroundColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  'Total Amount: ${widget.totalAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 40),

                // --- FIX: Using Wrap with the correct 'alignment' property ---
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.visibility),
                      label: const Text('Preview Receipt (PDF)'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 15,
                        ),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _handleReceiptPreview,
                    ),
                    // The thermal print button is commented out as planned
                    /* ElevatedButton.icon(
                      icon: _isPrinting ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.blue,)) : const Icon(Icons.print),
                      label: const Text('Print Thermal Receipt'),
                       style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade800,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        textStyle: const TextStyle(fontSize: 16),
                      ),
                      onPressed: _isPrinting ? null : _handlePrintReceipt,
                    ),
                    */
                  ],
                ),
                // -----------------------------------------------------------
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  icon: _isConfirming
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_circle),
                  label: const Text('Confirm Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 15,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: _isConfirming ? null : _confirmPayment,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
