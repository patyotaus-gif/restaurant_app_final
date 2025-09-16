// lib/customer_checkout_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'cart_provider.dart';
import 'models/promotion_model.dart';

class CustomerCheckoutPage extends StatefulWidget {
  final String tableNumber;
  final Map<String, CartItem> cart;
  final double totalAmount;
  final Promotion? appliedPromotion;
  final double discountAmount;

  const CustomerCheckoutPage({
    super.key,
    required this.tableNumber,
    required this.cart,
    required this.totalAmount,
    this.appliedPromotion,
    this.discountAmount = 0.0,
  });

  @override
  State<CustomerCheckoutPage> createState() => _CustomerCheckoutPageState();
}

class _CustomerCheckoutPageState extends State<CustomerCheckoutPage> {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  String _generatePromptPayPayload(double amount) {
    const promptPayId = "0812345678";
    return "promptpay-qr-for-$promptPayId-amount-$amount";
  }

  Future<void> _confirmPayment() async {
    if (widget.cart.isEmpty) return;
    setState(() {
      _isLoading = true;
    });

    final orderItems = widget.cart.values
        .map(
          (item) => {
            'id': item.id,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'category': item.category, // <-- FIX: Add category here
          },
        )
        .toList();

    final subtotal = widget.cart.values.fold(
      0.0,
      (total, item) => total + (item.price * item.quantity),
    );

    try {
      await FirebaseFirestore.instance.collection('orders').add({
        'items': orderItems,
        'subtotal': subtotal,
        'total': widget.totalAmount,
        'discount': widget.discountAmount,
        'discountType': widget.appliedPromotion != null ? 'promotion' : 'none',
        'promotionCode': widget.appliedPromotion?.code,
        'promotionDescription': widget.appliedPromotion?.description,
        'status':
            'completed', // Customer self-checkout goes straight to completed
        'timestamp': Timestamp.now(),
        'orderType': 'Dine-in',
        'orderIdentifier': 'Table ${widget.tableNumber}',
        'customerPhoneNumber': _phoneController.text,
      });

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Payment Confirmed!'),
            content: const Text(
              'Thank you! Your order is complete. A receipt will be sent shortly.',
            ),
            actions: [
              TextButton(
                child: const Text('OK'),
                onPressed: () {
                  Navigator.of(ctx).popUntil((route) => route.isFirst);
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final qrData = _generatePromptPayPayload(widget.totalAmount);
    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout for Table ${widget.tableNumber}'),
        backgroundColor: Colors.green,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text(
              'Scan QR to Pay',
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            const Text('Enter your phone number for a digital receipt:'),
            const SizedBox(height: 8),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle),
                label: const Text('I HAVE PAID - CONFIRM'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _confirmPayment,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
