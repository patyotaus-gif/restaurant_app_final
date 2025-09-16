// lib/cart_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'cart_provider.dart';
import 'checkout_page.dart';
import 'models/product_model.dart';
import 'auth_service.dart';
import 'widgets/manager_approval_dialog.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final _tableNumberController = TextEditingController();
  final _promoCodeController = TextEditingController();

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
  }

  @override
  void dispose() {
    _tableNumberController.dispose();
    _promoCodeController.dispose();
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
    return {
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
      'items': cart.items.values
          .map(
            (item) => {
              'id': item.id,
              'name': item.name,
              'quantity': item.quantity,
              'price': item.price,
              'description': item.description,
              'category': item.product.category,
            },
          )
          .toList(),
      'customerId': cart.customer?.id,
      'customerName': cart.customer?.name,
    };
  }

  void _sendToKitchen(CartProvider cart) {
    final orderData = _prepareOrderData(cart);
    if (orderData == null) return;
    FirebaseFirestore.instance.collection('orders').add(orderData);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Order sent to kitchen!')));
    cart.clear();
    Navigator.of(context).pop();
  }

  Future<void> _goToCheckout(CartProvider cart) async {
    final orderData = _prepareOrderData(cart);
    if (orderData == null) return;
    final docRef = await FirebaseFirestore.instance
        .collection('orders')
        .add(orderData);
    if (!mounted) return;

    final orderIdForCheckout = docRef.id;
    final totalAmountForCheckout = orderData['total'];
    final identifierForCheckout = orderData['orderIdentifier'];

    cart.clear();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => CheckoutPage(
          orderId: orderIdForCheckout,
          totalAmount: totalAmountForCheckout,
          orderIdentifier: identifierForCheckout,
        ),
      ),
    );
  }

  Widget _buildPointsSection(CartProvider cart) {
    if (cart.customer == null) return const SizedBox.shrink();
    final points = cart.customer!.loyaltyPoints;
    final maxDiscount = (points / 10).floor();
    if (points == 0) return const SizedBox.shrink();

    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: Icon(Icons.star, color: Colors.amber.shade700),
        title: Text('Use $points points'),
        subtitle: Text('Get a discount of $maxDiscount Baht'),
        trailing: ElevatedButton(
          onPressed: cart.discountType != 'none'
              ? null
              : () => cart.applyPointsDiscount(),
          child: const Text('Apply'),
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
      } else if (cart.discountType == 'manual') {
        discountLabel = 'Manual Discount';
      }

      return ListTile(
        title: Text(
          discountLabel,
          style: TextStyle(color: Colors.green.shade800),
        ),
        trailing: Text(
          '- ${cart.discount.toStringAsFixed(2)} บาท',
          style: TextStyle(color: Colors.green.shade800),
        ),
        leading: IconButton(
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
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(title: const Text('ตะกร้าสินค้า (Current Order)')),
          body: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15.0),
                child: _buildPointsSection(cart),
              ),
              Card(
                margin: const EdgeInsets.all(15),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      if (cart.orderType == OrderType.dineIn)
                        TextField(
                          controller: _tableNumberController,
                          decoration: const InputDecoration(
                            labelText: 'หมายเลขโต๊ะ (Table No.)',
                          ),
                          keyboardType: TextInputType.number,
                        )
                      else if (cart.orderType == OrderType.takeaway ||
                          cart.orderType == OrderType.retail)
                        ListTile(
                          title: const Text(
                            'Order Number',
                            style: TextStyle(color: Colors.grey),
                          ),
                          trailing: Text(
                            cart.orderIdentifier ?? '',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        )
                      else
                        const SizedBox.shrink(),
                      const SizedBox(height: 10),
                      ListTile(
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
                      const Divider(),
                      ListTile(
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
              Expanded(
                child: ListView.builder(
                  itemCount: cart.items.length,
                  itemBuilder: (ctx, i) {
                    final cartItem = cart.items.values.toList()[i];
                    return Dismissible(
                      key: ValueKey(cartItem.id),
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
                        ).removeItem(cartItem.id),
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
                                  () => cart.removeSingleItem(cartItem.id),
                                ),
                              ),
                              Text('${cartItem.quantity}'),
                              IconButton(
                                icon: const Icon(Icons.add),
                                onPressed: () {
                                  final success = cart.addItem(
                                    cartItem.product,
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
