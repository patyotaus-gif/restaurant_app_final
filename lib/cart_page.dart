// lib/cart_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_provider.dart';
import 'checkout_page.dart';
import 'models/product_model.dart';
import 'auth_service.dart';
import 'widgets/manager_approval_dialog.dart';
import 'services/sync_queue_service.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _tableNumberController = TextEditingController();
  final _promoCodeController = TextEditingController();
  final TextEditingController _serviceChargePercentController =
      TextEditingController();
  final TextEditingController _tipAmountController = TextEditingController();

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
    if (cart.orderType == OrderType.dineIn && cart.orderIdentifier != null) {
      _tableNumberController.text = cart.orderIdentifier!.replaceAll(
        'Table ',
        '',
      );
    }
    _serviceChargePercentController.text = _formatNumber(
      cart.serviceChargeRate * 100,
    );
    _tipAmountController.text = cart.tipAmount.toStringAsFixed(2);
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _promoCodeController.dispose();
    _serviceChargePercentController.dispose();
    _tipAmountController.dispose();
    super.dispose();
  }

  void _handleItemRemoval(BuildContext context, Function removalAction) {
    final auth = Provider.of<AuthService>(context, listen: false);
    if (auth.isManager || auth.isOwner) {
      removalAction();
    } else {
      showDialog(
        context: context,
        builder: (ctx) =>
            ManagerApprovalDialog(onApproved: () => removalAction()),
      );
    }
  }

  Map<String, dynamic>? _prepareOrderData(CartProvider cart) {
    if (cart.items.isEmpty || cart.orderIdentifier == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an order type first!'),
          backgroundColor: Colors.red,
        ),
      );
      return null;
    }
    final ingredientUsage = cart.ingredientUsage;
    return {
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
      'items': cart.items.values
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
              'description': item.description,
              'category': item.product.category,
              'recipe': item.recipe,
            },
          )
          .toList(),
      'customerId': cart.customer?.id,
      'customerName': cart.customer?.name,
      'ingredientUsage': ingredientUsage,
      'stockDeducted': false,
    };
  }

  Widget _buildSyncStatus(SyncQueueService syncQueue) {
    final isOffline = !syncQueue.isOnline;
    final pending = syncQueue.pendingCount;
    final error = syncQueue.lastError;
    final lastSynced = syncQueue.lastSyncedAt;

    if (!isOffline && pending == 0 && error == null) {
      return const SizedBox.shrink();
    }

    Color background;
    IconData icon;
    String message;
    String? details;

    if (isOffline) {
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

    if (lastSynced != null) {
      final localTime = lastSynced.toLocal();
      final timeOfDay = TimeOfDay.fromDateTime(localTime).format(context);
      final dateLabel = MaterialLocalizations.of(
        context,
      ).formatShortDate(localTime);
      details = 'Last synced $dateLabel at $timeOfDay';
    }

    return Container(
      width: double.infinity,
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.black54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (details != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4.0),
                    child: Text(
                      details!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (!isOffline && (pending > 0 || error != null))
            TextButton(
              onPressed: () => syncQueue.triggerSync(),
              child: const Text('Retry'),
            ),
        ],
      ),
    );
  }

  Future<void> _sendToKitchen(CartProvider cart) async {
    final orderData = _prepareOrderData(cart);
    if (orderData == null) return;
    final syncQueue = context.read<SyncQueueService>();

    try {
      final result = await syncQueue.enqueueAdd('orders', orderData);
      if (!mounted) return;
      final message = result.isSynced
          ? 'Order sent to kitchen!'
          : 'Offline: order queued and will sync automatically.';
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      cart.clear();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to send order: $e')));
    }
  }

  Future<void> _goToCheckout(CartProvider cart) async {
    final orderData = _prepareOrderData(cart);
    if (orderData == null) return;
    final syncQueue = context.read<SyncQueueService>();

    if (!syncQueue.isOnline) {
      await syncQueue.enqueueAdd('orders', orderData);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Offline mode: order queued. Checkout will be available once reconnected.',
          ),
        ),
      );
      cart.clear();
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }

    try {
      final result = await syncQueue.enqueueAdd('orders', orderData);
      if (!mounted) return;
      if (!result.isSynced || result.remoteDocumentId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to create order. Please try again.'),
          ),
        );
        return;
      }

      final orderIdForCheckout = result.remoteDocumentId!;
      final totalAmountForCheckout = orderData['total'];
      final identifierForCheckout = orderData['orderIdentifier'];

      cart.clear();

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => CheckoutPage(
            orderId: orderIdForCheckout,
            totalAmount: totalAmountForCheckout,
            orderIdentifier: identifierForCheckout,
            subtotal:
                (orderData['subtotal'] as num?)?.toDouble() ?? cart.subtotal,
            discountAmount:
                (orderData['discount'] as num?)?.toDouble() ?? cart.discount,
            serviceChargeAmount:
                (orderData['serviceChargeAmount'] as num?)?.toDouble() ?? 0.0,
            serviceChargeRate:
                (orderData['serviceChargeRate'] as num?)?.toDouble() ?? 0.0,
            tipAmount: (orderData['tipAmount'] as num?)?.toDouble() ?? 0.0,
            splitCount: (orderData['splitCount'] as num?)?.toInt() ?? 1,
            splitAmountPerGuest: (orderData['splitAmountPerGuest'] as num?)
                ?.toDouble(),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Unable to start checkout: $e')));
    }
  }

  Widget _buildPointsSection(CartProvider cart) {
    if (cart.customer == null) return const SizedBox.shrink();
    final points = cart.customer!.loyaltyPoints;
    final maxDiscount = (points / 10).floor();
    if (points == 0) return const SizedBox.shrink();

    final hasPointsDiscount = cart.discountType == 'points';
    final hasOtherDiscount = cart.discountType != 'none' && !hasPointsDiscount;

    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: Icon(Icons.star, color: Colors.amber.shade700),
        title: Text('Use $points points'),
        subtitle: Text('Get a discount of $maxDiscount Baht'),
        trailing: ElevatedButton(
          onPressed: hasOtherDiscount
              ? null
              : () {
                  if (hasPointsDiscount) {
                    cart.removeDiscount();
                  } else {
                    cart.applyPointsDiscount();
                  }
                },
          child: Text(hasPointsDiscount ? 'Reset' : 'Redeem'),
        ),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _promoCodeController,
              decoration: const InputDecoration(
                labelText: 'Promotion Code',
                isDense: true,
              ),
              onSubmitted: (value) => _applyPromo(cart),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _applyPromo(cart),
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceChargeSection(CartProvider cart) {
    if (cart.orderType != OrderType.dineIn) {
      return const SizedBox.shrink();
    }

    final percentText = _formatNumber(cart.serviceChargeRate * 100);
    if (_serviceChargePercentController.text != percentText) {
      _serviceChargePercentController.text = percentText;
    }

    return Column(
      children: [
        SwitchListTile.adaptive(
          title: const Text('Service Charge'),
          subtitle: Text(
            cart.serviceChargeEnabled
                ? '+ ${cart.serviceChargeAmount.toStringAsFixed(2)} บาท'
                : 'Tap to add a service charge',
          ),
          value: cart.serviceChargeEnabled,
          onChanged: (value) {
            cart.setServiceChargeEnabled(value);
          },
        ),
        if (cart.serviceChargeEnabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
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

    final tipText = cart.tipAmount.toStringAsFixed(2);
    if (_tipAmountController.text != tipText) {
      _tipAmountController.text = tipText;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Card(
        elevation: 0,
        color: Colors.blueGrey.shade50,
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
      ),
    );
  }

  void _applyPromo(CartProvider cart) async {
    final code = _promoCodeController.text;
    final result = await cart.applyPromotionCode(code);
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result)));
      _promoCodeController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<CartProvider, SyncQueueService>(
      builder: (context, cart, syncQueue, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('ตะกร้าสินค้า (Current Order)')),
          body: Column(
            children: <Widget>[
              _buildSyncStatus(syncQueue),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: _buildPointsSection(cart),
              ),
              Card(
                margin: const EdgeInsets.symmetric(
                  horizontal: 15.0,
                  vertical: 8.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (cart.orderIdentifier != null)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Order Number',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Text(
                            cart.orderIdentifier!,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Subtotal',
                          style: TextStyle(fontSize: 16),
                        ),
                        trailing: Text(
                          '${cart.subtotal.toStringAsFixed(2)} บาท',
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      _buildPromotionSection(cart),
                      _buildServiceChargeSection(cart),
                      _buildTipSection(cart),
                      if (cart.serviceChargeEnabled)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Service Charge (${_formatNumber(cart.serviceChargeRate * 100)}%)',
                          ),
                          trailing: Text(
                            '+ ${cart.serviceChargeAmount.toStringAsFixed(2)} บาท',
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      if (cart.tipAmount > 0)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Tip'),
                          trailing: Text(
                            '+ ${cart.tipAmount.toStringAsFixed(2)} บาท',
                            style: const TextStyle(color: Colors.deepOrange),
                          ),
                        ),
                      const Divider(),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        trailing: Text(
                          '${cart.totalAmount.toStringAsFixed(2)} บาท',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              _buildSplitBillSection(cart),
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (ctx, i) {
                    final itemKey = cart.items.keys.toList()[i];
                    final cartItem = cart.items.values.toList()[i];
                    return Dismissible(
                      key: ValueKey(itemKey),
                      background: Container(
                        color: Theme.of(context).colorScheme.error,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.only(right: 20),
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        child: const Icon(
                          Icons.delete,
                          color: Colors.white,
                          size: 40,
                        ),
                      ),
                      direction: DismissDirection.endToStart,
                      onDismissed: (direction) => _handleItemRemoval(
                        context,
                        () => Provider.of<CartProvider>(
                          context,
                          listen: false,
                        ).removeItem(itemKey),
                      ),
                      child: Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 15,
                          vertical: 4,
                        ),
                        child: ListTile(
                          title: Text(cartItem.name),
                          subtitle: Text(
                            'Price: ${cartItem.price.toStringAsFixed(2)} บาท',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.remove),
                                onPressed: () => _handleItemRemoval(
                                  context,
                                  () => cart.removeSingleItem(itemKey),
                                ),
                              ),
                              Text('${cartItem.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  final success = cart.addItem(
                                    cartItem.product,
                                    modifiers: cartItem.selectedModifiers,
                                  );
                                  if (!success) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'สินค้าในสต็อกไม่เพียงพอ!',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    if (cart.orderType != OrderType.retail)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _sendToKitchen(cart),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            side: BorderSide(
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          child: const Text('Send to Kitchen'),
                        ),
                      ),
                    if (cart.orderType != OrderType.retail)
                      const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _goToCheckout(cart),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Go to Checkout'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
