// lib/item_refund_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'auth_service.dart';
import 'stock_provider.dart';

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
  String _refundMethod = 'cash';
  final TextEditingController _giftCardCodeController = TextEditingController();
  final TextEditingController _exchangeNotesController =
      TextEditingController();
  final GiftCardService _giftCardService = GiftCardService();

  @override
  void initState() {
    super.initState();
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final List<dynamic> originalItems = orderData['items'] ?? [];
    _itemsToRefund = originalItems.map((item) => RefundableItem(item)).toList();
  }

  @override
  void dispose() {
    _giftCardCodeController.dispose();
    _exchangeNotesController.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> _calculateRestockUsage() {
    final Map<String, Map<String, dynamic>> aggregated = {};

    for (final item in _itemsToRefund) {
      if (item.refundQuantity <= 0) continue;
      final recipe = item.originalItem['recipe'];
      if (recipe is! List) continue;

      for (final ingredient in recipe) {
        if (ingredient is! Map<String, dynamic>) continue;
        final ingredientId = ingredient['ingredientId'] as String?;
        if (ingredientId == null || ingredientId.isEmpty) continue;
        final perUnitQuantity =
            (ingredient['quantity'] as num?)?.toDouble() ?? 0.0;
        if (perUnitQuantity <= 0) continue;

        final ingredientName =
            ingredient['ingredientName'] ?? ingredient['name'] ?? '';
        final unit = ingredient['unit'] ?? ingredient['ingredientUnit'] ?? '';
        final totalQuantity = perUnitQuantity * item.refundQuantity;

        aggregated.update(
          ingredientId,
          (existing) {
            final current = (existing['quantity'] as num?)?.toDouble() ?? 0.0;
            return {
              'ingredientId': ingredientId,
              'ingredientName': ingredientName,
              'unit': unit,
              'quantity': current + totalQuantity,
            };
          },
          ifAbsent: () => {
            'ingredientId': ingredientId,
            'ingredientName': ingredientName,
            'unit': unit,
            'quantity': totalQuantity,
          },
        );
      }
    }

    return aggregated.values
        .map(
          (value) => {
            'ingredientId': value['ingredientId'],
            'ingredientName': value['ingredientName'],
            'unit': value['unit'],
            'quantity': (value['quantity'] as num?)?.toDouble() ?? 0.0,
          },
        )
        .toList();
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one item to refund.'),
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    final firestore = FirebaseFirestore.instance;
    final auth = Provider.of<AuthService>(context, listen: false);
    final userRole = auth.currentRole.toString();
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final String? customerId = orderData['customerId'] as String?;

    if (_refundMethod == 'storeCredit' && customerId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cannot apply store credit without a customer.'),
          ),
        );
      }
      setState(() {
        _isProcessing = false;
      });
      return;
    }

    final restockUsage = _calculateRestockUsage();

    final batch = firestore.batch();

    final refundDocRef = firestore.collection('refunds').doc();
    batch.set(refundDocRef, {
      'originalOrderId': widget.orderDoc.id,
      'refundTimestamp': Timestamp.now(),
      'totalRefundAmount': _totalRefundAmount,
      'refundedItems': refundedItems,
      'processedByRole': userRole,
      'refundMethod': _refundMethod,
      if (_refundMethod == 'giftCard')
        'giftCardCode': _giftCardCodeController.text.trim().isEmpty
            ? null
            : _giftCardCodeController.text.trim().toUpperCase(),
      if (_refundMethod == 'storeCredit') 'storeCreditCustomerId': customerId,
      if (_refundMethod == 'exchange')
        'exchangeNotes': _exchangeNotesController.text.trim(),
      'inventoryReversed': restockUsage.isNotEmpty,
      if (restockUsage.isNotEmpty) 'restockedIngredients': restockUsage,
    });

    final orderDocRef = firestore.collection('orders').doc(widget.orderDoc.id);
    batch.update(orderDocRef, {'hasPartialRefund': true});

    try {
      if (!mounted) return;
      await batch.commit();

      if (restockUsage.isNotEmpty) {
        if (!mounted) return;
        await Provider.of<StockProvider>(
          context,
          listen: false,
        ).restockIngredientsFromUsage(restockUsage);
      }

      GiftCard? issuedGiftCard;
      if (_refundMethod == 'storeCredit' && customerId != null) {
        await firestore.collection('customers').doc(customerId).update({
          'storeCredit': FieldValue.increment(_totalRefundAmount),
        });
      } else if (_refundMethod == 'giftCard' && _totalRefundAmount > 0) {
        final code = _giftCardCodeController.text.trim().isEmpty
            ? null
            : _giftCardCodeController.text.trim();
        issuedGiftCard = await _giftCardService.issueOrTopUp(
          code: code,
          amount: _totalRefundAmount,
          customerId: customerId,
        );
      }

      if (mounted) {
        String message =
            'Refund of ${_totalRefundAmount.toStringAsFixed(2)} Baht processed successfully.';
        if (_refundMethod == 'storeCredit') {
          message =
              'Refund credited to customer account: ${_totalRefundAmount.toStringAsFixed(2)} Baht.';
        } else if (_refundMethod == 'giftCard' && issuedGiftCard != null) {
          message =
              'Refund added to gift card ${issuedGiftCard.code}: ${_totalRefundAmount.toStringAsFixed(2)} Baht.';
        } else if (_refundMethod == 'exchange') {
          message =
              'Exchange recorded. Inventory has been replenished for returned items.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Colors.green),
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
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
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
          _buildRefundMethodCard(orderData),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromRGBO(0, 0, 0, 0.1),
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

  Widget _buildRefundMethodCard(Map<String, dynamic> orderData) {
    final hasCustomer = (orderData['customerId'] as String?) != null;
    final customerName = orderData['customerName']?.toString() ?? 'Guest';

    return Card(
      margin: const EdgeInsets.all(16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Refund Method',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _refundMethod,
              items: [
                const DropdownMenuItem(
                  value: 'cash',
                  child: Text('Cash / Original Payment'),
                ),
                const DropdownMenuItem(
                  value: 'giftCard',
                  child: Text('Gift Card'),
                ),
                DropdownMenuItem(
                  value: 'storeCredit',
                  enabled: hasCustomer,
                  child: Text(
                    hasCustomer
                        ? 'Store Credit ($customerName)'
                        : 'Store Credit (customer required)',
                  ),
                ),
                const DropdownMenuItem(
                  value: 'exchange',
                  child: Text('Exchange Only (no payout)'),
                ),
              ],
              onChanged: _isProcessing
                  ? null
                  : (value) {
                      if (value == null) return;
                      if (value == 'storeCredit' && !hasCustomer) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Store credit is only available when a customer is attached to the order.',
                            ),
                          ),
                        );
                        return;
                      }
                      setState(() {
                        _refundMethod = value;
                      });
                    },
            ),
            if (_refundMethod == 'giftCard') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _giftCardCodeController,
                decoration: const InputDecoration(
                  labelText: 'Gift Card Code (leave blank to auto-generate)',
                  border: OutlineInputBorder(),
                ),
                textCapitalization: TextCapitalization.characters,
              ),
            ],
            if (_refundMethod == 'exchange') ...[
              const SizedBox(height: 12),
              TextField(
                controller: _exchangeNotesController,
                decoration: const InputDecoration(
                  labelText: 'Exchange Notes',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
            ],
            if (_refundMethod == 'storeCredit' && hasCustomer)
              Padding(
                padding: const EdgeInsets.only(top: 12.0),
                child: Text(
                  'Refund will be added to $customerName\'s store credit.',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
