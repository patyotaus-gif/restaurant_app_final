// lib/item_refund_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../auth_service.dart';

class RefundableItem {
  final Map<String, dynamic> originalItem;
  int refundQuantity = 0;

  RefundableItem(this.originalItem);

  // --- FIX: เพิ่มการตรวจสอบค่า null เพื่อป้องกันแอปค้าง ---
  // ถ้าไม่เจอ 'id' ให้ใช้ค่าว่าง '' แทน
  String get id => originalItem['id'] ?? '';
  // ---------------------------------------------------

  String get name => originalItem['name'];
  int get originalQuantity => originalItem['quantity'];
  double get pricePerItem => (originalItem['price'] as num).toDouble();
}

class ItemRefundPage extends StatefulWidget {
  final DocumentSnapshot orderDoc;

  const ItemRefundPage({super.key, required this.orderDoc});

  @override
  State<ItemRefundPage> createState() => _ItemRefundPageState();
}

class _ItemRefundPageState extends State<ItemRefundPage> {
  late List<RefundableItem> _itemsToRefund;
  double _totalRefundAmount = 0.0;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final List<dynamic> originalItems = orderData['items'] ?? [];
    _itemsToRefund = originalItems.map((item) => RefundableItem(item)).toList();
  }

  void _updateRefundTotal() {
    double total = 0;
    for (var item in _itemsToRefund) {
      total += item.refundQuantity * item.pricePerItem;
    }
    setState(() {
      _totalRefundAmount = total;
    });
  }

  void _incrementRefund(RefundableItem item) {
    if (item.refundQuantity < item.originalQuantity) {
      setState(() {
        item.refundQuantity++;
      });
      _updateRefundTotal();
    }
  }

  void _decrementRefund(RefundableItem item) {
    if (item.refundQuantity > 0) {
      setState(() {
        item.refundQuantity--;
      });
      _updateRefundTotal();
    }
  }

  Future<void> _processRefund() async {
    setState(() {
      _isProcessing = true;
    });

    final refundedItems = _itemsToRefund
        .where((item) => item.refundQuantity > 0)
        .map(
          (item) => {
            'menuItemId': item.id,
            'name': item.name,
            'price': item.pricePerItem,
            'quantity': item.refundQuantity,
          },
        )
        .toList();

    if (refundedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one item to refund.'),
        ),
      );
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final auth = Provider.of<AuthService>(context, listen: false);
    final userRole = auth.currentRole.toString();

    final batch = firestore.batch();

    final refundDocRef = firestore.collection('refunds').doc();
    batch.set(refundDocRef, {
      'originalOrderId': widget.orderDoc.id,
      'refundTimestamp': Timestamp.now(),
      'totalRefundAmount': _totalRefundAmount,
      'refundedItems': refundedItems,
      'processedByRole': userRole,
    });

    final orderDocRef = firestore.collection('orders').doc(widget.orderDoc.id);
    batch.update(orderDocRef, {'hasPartialRefund': true});

    try {
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Refund of ${_totalRefundAmount.toStringAsFixed(2)} Baht processed successfully.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to process refund: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final orderIdentifier = orderData['orderIdentifier'] ?? 'N/A';

    return Scaffold(
      appBar: AppBar(title: Text('Refund for: $orderIdentifier')),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: _itemsToRefund.length,
              itemBuilder: (context, index) {
                final item = _itemsToRefund[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    'Ordered: ${item.originalQuantity} @ ${item.pricePerItem.toStringAsFixed(2)} each',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        onPressed: _isProcessing
                            ? null
                            : () => _decrementRefund(item),
                        color: Colors.red,
                      ),
                      Text(
                        '${item.refundQuantity}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        onPressed: _isProcessing
                            ? null
                            : () => _incrementRefund(item),
                        color: Colors.green,
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Refund:',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${_totalRefundAmount.toStringAsFixed(2)} Baht',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (_totalRefundAmount > 0 && !_isProcessing)
                        ? _processRefund
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isProcessing
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Confirm Refund'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
