// lib/widgets/order_dashboard/cart_summary_panel.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../../cart_provider.dart';
import '../../checkout_page.dart';
import '../../services/sync_queue_service.dart';
import '../customer_header_widget.dart';
class CartSummaryPanel extends StatefulWidget {
  const CartSummaryPanel({super.key});

  @override
  State<CartSummaryPanel> createState() => _CartSummaryPanelState();
}

class _CartSummaryPanelState extends State<CartSummaryPanel> {
  final _promoCodeController = TextEditingController();
  final TextEditingController _serviceChargePercentController =
      TextEditingController();
  final TextEditingController _tipAmountController = TextEditingController();

  late final CartProvider _cart;
  VoidCallback? _cartListener;

  String _formatNumber(double value) {
    var text = value.toStringAsFixed(2);
    if (!text.contains('.')) return text;
    while (text.endsWith('0')) {
      text = text.substring(0, text.length - 1);
    }
    if (text.endsWith('.')) {
      text = text.substring(0, text.length - 1);
    }
    return text;
  }

  @override
  void initState() {
    super.initState();
    final cart = Provider.of<CartProvider>(context, listen: false);
    _cart = cart;
    _syncControllers();
    _cartListener = () {
      if (!mounted) return;
      _syncControllers();
    };
    cart.addListener(_cartListener!);
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    _serviceChargePercentController.dispose();
    _tipAmountController.dispose();
    final listener = _cartListener;
    if (listener != null) {
      _cart.removeListener(listener);
    }
    super.dispose();
  }

  void _syncControllers() {
    final percentText = _formatNumber(_cart.serviceChargeRate * 100);
    if (_serviceChargePercentController.text != percentText) {
      _serviceChargePercentController.value = TextEditingValue(
        text: percentText,
        selection: TextSelection.collapsed(offset: percentText.length),
      );
    }

    final tipText = _cart.tipAmount.toStringAsFixed(2);
    if (_tipAmountController.text != tipText) {
      _tipAmountController.value = TextEditingValue(
        text: tipText,
        selection: TextSelection.collapsed(offset: tipText.length),
      );
    }
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

  Widget _buildServiceChargeSection(CartProvider cart) {
    if (cart.orderType != OrderType.dineIn) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Service Charge'),
          subtitle: Text(
            cart.serviceChargeEnabled
                ? '+ ${cart.serviceChargeAmount.toStringAsFixed(2)} บาท'
                : 'Tap to add a service charge',
          ),
          value: cart.serviceChargeEnabled,
          onChanged: (value) => cart.setServiceChargeEnabled(value),
        ),
        if (cart.serviceChargeEnabled)
          Padding(
            padding: const EdgeInsets.only(left: 12.0, right: 12.0, bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _serviceChargePercentController,
                    decoration: const InputDecoration(
                      labelText: 'Service Charge %',
                      suffixText: '%',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (value) {
                      final parsed = double.tryParse(value);
                      if (parsed != null) {
                        cart.setServiceChargeRate(parsed / 100);
                      } else if (value.trim().isEmpty) {
                        cart.setServiceChargeRate(0);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  '+ ${cart.serviceChargeAmount.toStringAsFixed(2)} บาท',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildTipSection(CartProvider cart) {
    if (cart.orderType != OrderType.dineIn) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tip',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _tipAmountController,
            decoration: const InputDecoration(
              labelText: 'Tip Amount',
              prefixText: '฿ ',
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final parsed = double.tryParse(value);
              if (parsed != null) {
                cart.setTipAmount(parsed);
              } else if (value.trim().isEmpty) {
                cart.setTipAmount(0);
              }
            },
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final percent in [0, 5, 10, 15])
                OutlinedButton(
                  onPressed: () {
                    final base = cart.subtotal - cart.discount;
                    final baseNonNegative = base < 0 ? 0 : base;
                    cart.setTipAmount(baseNonNegative * (percent / 100));
                  },
                  child: Text('$percent%'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSplitBillSection(CartProvider cart) {
    if (cart.orderType != OrderType.dineIn) {
      return const SizedBox.shrink();
    }

    final splitCount = cart.splitCount;
    final perGuest = cart.splitAmountPerGuest;

    return Card(
      color: Colors.blueGrey.shade50,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Split Bill',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Number of guests'),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: splitCount > 1
                          ? () => cart.decrementSplitCount()
                          : null,
                    ),
                    Text('$splitCount'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: cart.incrementSplitCount,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Each guest pays: ${perGuest.toStringAsFixed(2)} บาท',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<String?> _createOrUpdateOrder(
    CartProvider cart,
    SyncQueueService syncQueue,
  ) async {
    final ingredientUsage = cart.ingredientUsage;
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
            'recipe': item.recipe,
            'kitchenStations': item.kitchenStations,
            'prepTimeMinutes': item.prepTimeMinutes,
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
      'serviceChargeEnabled': cart.serviceChargeEnabled,
      'serviceChargeRate': cart.serviceChargeRate,
      'serviceChargeAmount': cart.serviceChargeAmount,
      'tipAmount': cart.tipAmount,
      'splitCount': cart.splitCount,
      'splitAmountPerGuest': cart.splitAmountPerGuest,
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
      'ingredientUsage': ingredientUsage,
      'stockDeducted': false,
      'slaMinutes': cart.prepTimeSlaMinutes,
      'kdsAcknowledged': false,
      'kdsAcknowledgedAt': null,
      'kdsAcknowledgedBy': null,
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
          Flexible(
            fit: FlexFit.loose,
            child: SafeArea(
              top: false,
              child: Container(
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
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (cart.orderType == OrderType.dineIn) ...[
                        _buildServiceChargeSection(cart),
                        const SizedBox(height: 8),
                        _buildTipSection(cart),
                        _buildSplitBillSection(cart),
                        const SizedBox(height: 12),
                      ],
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
                      if (cart.serviceChargeEnabled)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              Text(
                                'Service Charge (${_formatNumber(cart.serviceChargeRate * 100)}%)',
                              ),
                              Text(
                                '+ ${cart.serviceChargeAmount.toStringAsFixed(2)} บาท',
                                style: const TextStyle(color: Colors.deepOrange),
                              ),
                            ],
                          ),
                        ),
                      if (cart.tipAmount > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: <Widget>[
                              const Text('Tip'),
                              Text(
                                '+ ${cart.tipAmount.toStringAsFixed(2)} บาท',
                                style: const TextStyle(color: Colors.deepOrange),
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
                      if (cart.orderType == OrderType.dineIn && cart.splitCount > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            'Split between ${cart.splitCount} guests: ${cart.splitAmountPerGuest.toStringAsFixed(2)} บาท each',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
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
              ),
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
