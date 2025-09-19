// lib/widgets/order_dashboard/cart_summary_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../../cart_provider.dart';
import '../../checkout_page.dart';
import '../customer_header_widget.dart';
import '../../models/punch_card_model.dart';
import '../../services/sync_queue_service.dart';

class CartSummaryPanel extends StatefulWidget {
  const CartSummaryPanel({super.key});

  @override
  State<CartSummaryPanel> createState() => _CartSummaryPanelState();
}

class _CartSummaryPanelState extends State<CartSummaryPanel> {
  final _promoCodeController = TextEditingController();

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Widget _buildSyncStatus(SyncQueueService syncQueue) {
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
          ? 'Offline mode: $pending queued order(s) will sync later.'
          : 'Offline mode: new orders will sync when online.';
    } else if (pending > 0) {
      background = Colors.blue.shade100;
      icon = Icons.sync;
      message = 'Syncing $pending pending order(s)...';
    } else {
      background = Colors.red.shade100;
      icon = Icons.error_outline;
      message = 'Sync error: ${error ?? 'Please retry.'}';
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
          if (!offline && (pending > 0 || error != null))
            TextButton(
              onPressed: () => syncQueue.triggerSync(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Future<String?> _createOrUpdateOrder(
    CartProvider cart,
    SyncQueueService syncQueue,
  ) async {
    final itemsToSave = cart.items.values
        .map(
          (item) => {
            'id': item.id,
            'name': item.name,
            'quantity': item.quantity,
            'price': item.price,
            'description': item.description,
            'category': item.category,
            'selectedModifiers': item.selectedModifiers,
          },
        )
        .toList();

    final orderPayload = {
      'total': cart.totalAmount,
      'subtotal': cart.subtotal,
      'discount': cart.discount,
      'discountType': cart.discountType,
      'promotionCode': cart.appliedPromotion?.code,
      'promotionDescription': cart.appliedPromotion?.description,
      'pointsRedeemed': cart.discountType == 'points'
          ? (cart.discount * 10).floor()
          : 0,
      'timestamp': Timestamp.now(),
      'status': 'preparing',
      'orderIdentifier': cart.orderIdentifier,
      'orderType': cart.orderType.toString().split('.').last,
      'items': itemsToSave,
      'customerId': cart.customer?.id,
      'customerName': cart.customer?.name,
    };

    if (!syncQueue.isOnline) {
      await syncQueue.enqueueAdd('orders', orderPayload);
      return null;
    }

    final snapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('orderIdentifier', isEqualTo: cart.orderIdentifier)
        .where('status', whereNotIn: ['completed', 'refunded'])
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      final orderId = snapshot.docs.first.id;
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .update(orderPayload);
      return orderId;
    } else {
      final result = await syncQueue.enqueueAdd('orders', orderPayload);
      return result.remoteDocumentId;
    }
  }

  void _sendOrderToKitchen(CartProvider cart) async {
    if (cart.items.isEmpty || cart.orderIdentifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // <-- FIXED
          content: Text('Cart is empty or no order type selected!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final syncQueue = context.read<SyncQueueService>();

    try {
      await _createOrUpdateOrder(cart, syncQueue);
      if (mounted) {
        final message = syncQueue.isOnline
            ? 'Order sent to kitchen!'
            : 'Offline: order queued and will sync automatically.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message))); // <-- FIXED
        cart.clear();
        context.go('/order-type-selection');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending order: $e')),
        ); // <-- FIXED //
      }
    }
  }

  void _navigateToCheckout(CartProvider cart) {
    if (cart.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // <-- FIXED
          content: Text('Cannot proceed with an empty cart.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    if (cart.orderIdentifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // <-- FIXED
          content: Text('Please select an order type first!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    context.push('/cart');
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close Order',
          onPressed: () {
            Provider.of<CartProvider>(context, listen: false).clear();
            context.go('/order-type-selection');
          },
        ),
        title: Text(cart.orderIdentifier ?? 'Current Order'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Column(
        children: <Widget>[
          Consumer<SyncQueueService>(
            builder: (context, syncQueue, child) => _buildSyncStatus(syncQueue),
          ),
          const CustomerHeaderWidget(),
          const Divider(height: 1),
          _buildPromotionSection(cart),
          const Divider(height: 1),
          Expanded(
            child: cart.items.isEmpty
                ? const Center(child: Text('No items in cart'))
                : ListView.builder(
                    itemCount: cart.items.length,
                    itemBuilder: (ctx, i) {
                      final item = cart.items.values.toList()[i];
                      final itemId = cart.items.keys.toList()[i];

                      final modifierWidgets = item.selectedModifiers.map((mod) {
                        return Padding(
                          padding: const EdgeInsets.only(left: 16.0),
                          child: Text(
                            '  - ${mod['optionName']} (+${(mod['priceChange'] as num).toStringAsFixed(2)})',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 12,
                            ),
                          ),
                        );
                      }).toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.quantity} x ${item.priceWithModifiers.toStringAsFixed(2)}',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  (item.priceWithModifiers * item.quantity)
                                      .toStringAsFixed(2),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.red,
                                  ),
                                  onPressed: () {
                                    cart.removeItem(itemId);
                                  },
                                ),
                              ],
                            ),
                          ),
                          ...modifierWidgets,
                        ],
                      );
                    },
                  ),
          ),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(
                    (255 * 0.1).round(),
                  ), // <-- FIXED
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text('Subtotal'),
                    Text('${cart.subtotal.toStringAsFixed(2)} บาท'),
                  ],
                ),
                if (cart.discount > 0)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text('Discount (${cart.discountType})'),
                        Text(
                          '-${cart.discount.toStringAsFixed(2)} บาท',
                          style: TextStyle(color: Colors.green.shade700),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${cart.totalAmount.toStringAsFixed(2)} บาท',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => _sendOrderToKitchen(cart),
                        child: const Text('Send to Kitchen'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                        onPressed: () => _navigateToCheckout(cart),
                        child: const Text('Payment'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionSection(CartProvider cart) {
    if (cart.discountType != 'none') {
      String discountLabel = 'Discount';
      if (cart.discountType == 'promotion') {
        discountLabel = "Promotion (${cart.appliedPromotion?.code ?? ''})";
      } else if (cart.discountType == 'points') {
        discountLabel = 'Points Redemption';
      }
      return ListTile(
        dense: true,
        leading: Icon(Icons.check_circle, color: Colors.green.shade700),
        title: Text(discountLabel),
        trailing: IconButton(
          icon: const Icon(Icons.clear, size: 18),
          onPressed: () => cart.removeDiscount(),
        ),
      );
    }

    return ListTile(
      title: TextField(
        controller: _promoCodeController,
        decoration: const InputDecoration(
          labelText: 'Promotion Code',
          isDense: true,
        ),
        onSubmitted: (value) => _applyPromo(cart),
      ),
      trailing: ElevatedButton(
        onPressed: () => _applyPromo(cart),
        child: const Text('Apply'),
      ),
    );
  }

  void _applyPromo(CartProvider cart) async {
    if (_promoCodeController.text.isEmpty) return;
    final code = _promoCodeController.text;
    final result = await cart.applyPromotionCode(code);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result))); // <-- FIXED
      _promoCodeController.clear();
      FocusScope.of(context).unfocus();
    }
  }
}
