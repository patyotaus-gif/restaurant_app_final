// lib/customer_checkout_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:url_launcher/url_launcher.dart';

import 'cart_provider.dart';
import 'services/sync_queue_service.dart';
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

  Widget _buildSyncBanner(SyncQueueService syncQueue) {
    final offline = !syncQueue.isOnline;
    final pending = syncQueue.pendingCount;
    final error = syncQueue.lastError;

    if (!offline && pending == 0 && error == null) {
      return const SizedBox.shrink();
    }

    Color background;
    IconData icon;
    String message;

    if (offline) {
      background = Colors.orange.shade100;
      icon = Icons.wifi_off;
      message = pending > 0
          ? 'You are offline. $pending order(s) will sync automatically.'
          : 'You are offline. New orders will sync once reconnected.';
    } else if (pending > 0) {
      background = Colors.blue.shade100;
      icon = Icons.sync;
      message = 'Syncing $pending pending order(s)...';
    } else {
      background = Colors.red.shade100;
      icon = Icons.error_outline;
      message = 'Sync error: ${error ?? 'Please try again.'}';
    }

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
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

    final syncQueue = context.read<SyncQueueService>();

    try {
      final result = await syncQueue.enqueueAdd('orders', {
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

      final isSynced = result.isSynced;
      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Text(isSynced ? 'Payment Confirmed!' : 'Payment Queued'),
          content: Text(
            isSynced
                ? 'Thank you! Your order is complete. A receipt will be sent shortly.'
                : 'You are offline. Your payment has been queued and will sync automatically when connected.',
          ),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Checkout for Table ${widget.tableNumber}'),
        backgroundColor: Colors.green,
      ),
      body: Consumer<SyncQueueService>(
        builder: (context, syncQueue, child) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSyncBanner(syncQueue),
                Card(
                  elevation: 0,
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Card payments powered by omise-node',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ) ??
                              const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Our staff will present a secure Omise terminal to complete your payment. Once the transaction succeeds, tap confirm to notify the system.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () async {
                              final uri = Uri.parse('https://github.com/omise/omise-node');
                              final launched = await launchUrl(
                                uri,
                                mode: LaunchMode.externalApplication,
                              );
                              if (!launched) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Unable to open Omise documentation.'),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: const Text('Learn about omise-node'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Total Amount: ${widget.totalAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
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
                    icon: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Icon(Icons.check_circle),
                    label: Text(_isLoading ? 'Processing...' : 'Confirm Payment'),
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
          );
        },
      ),
    );
  }
}
