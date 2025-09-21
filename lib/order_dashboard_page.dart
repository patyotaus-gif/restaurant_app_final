// lib/order_dashboard_page.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_provider.dart';
import 'models/product_model.dart';
import 'widgets/order_dashboard/category_panel.dart';
import 'widgets/order_dashboard/menu_grid_panel.dart';
import 'widgets/order_dashboard/cart_summary_panel.dart';

class OrderDashboardPage extends StatefulWidget {
  final String? orderId;
  final int? tableNumber;

  const OrderDashboardPage({super.key, this.orderId, this.tableNumber});

  @override
  State<OrderDashboardPage> createState() => _OrderDashboardPageState();
}

class _OrderDashboardPageState extends State<OrderDashboardPage> {
  String _selectedCategory = 'soft_drinks';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadOrCreateOrder();
    });
  }

  void _onCategorySelected(String categoryKey) {
    setState(() {
      _selectedCategory = categoryKey;
    });
  }

  void _loadOrCreateOrder() {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (widget.orderId != null || widget.tableNumber != null) {
      cart.clear();

      if (widget.orderId != null) {
        _loadExistingOrder(widget.orderId!);
      } else if (widget.tableNumber != null) {
        cart.selectDineIn(widget.tableNumber!);
      }
    }
  }

  Future<void> _loadExistingOrder(String orderId) async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    try {
      final orderDoc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .get();
      if (!mounted) return;
      if (orderDoc.exists) {
        final orderData = orderDoc.data()!;
        final itemsList = (orderData['items'] ?? []) as List<dynamic>;
        final customerId = orderData['customerId'];

        final Map<String, CartItem> loadedItems = {};
        for (var itemData in itemsList) {
          final tempProduct = Product(
            id: itemData['id'],
            name: itemData['name'],
            price: (itemData['price'] as num).toDouble(),
            description: itemData['description'] ?? '',
            imageUrl: itemData['imageUrl'] ?? '',
            category: itemData['category'] ?? '',
            modifierGroupIds: List<String>.from(
              itemData['modifierGroupIds'] ?? [],
            ),
            kitchenStations: List<String>.from(
              itemData['kitchenStations'] ?? const [],
            ),
            prepTimeMinutes:
                (itemData['prepTimeMinutes'] as num?)?.toDouble() ?? 0.0,
          );

          final cartItem = CartItem(
            product: tempProduct,
            quantity: itemData['quantity'],
            selectedModifiers: List<Map<String, dynamic>>.from(
              itemData['selectedModifiers'] ?? [],
            ),
          );

          final modifiersKey = cartItem.selectedModifiers
              .map((m) => '${m['groupName']}:${m['optionName']}')
              .join('_');
          final itemKey = '${tempProduct.id}_$modifiersKey';
          loadedItems[itemKey] = cartItem;
        }

        cart.loadOrder(
          loadedItems,
          orderData['orderIdentifier'],
          serviceChargeEnabled: orderData['serviceChargeEnabled'] ?? false,
          serviceChargeRate: (orderData['serviceChargeRate'] as num?)
              ?.toDouble(),
          tipAmount: (orderData['tipAmount'] as num?)?.toDouble() ?? 0.0,
          splitCount: (orderData['splitCount'] as num?)?.toInt() ?? 1,
        );

        if (customerId != null) {
          final customerDoc = await FirebaseFirestore.instance
              .collection('customers')
              .doc(customerId)
              .get();
          if (customerDoc.exists) {
            cart.setCustomer(customerDoc);
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading order: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          const Expanded(flex: 3, child: CartSummaryPanel()),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 5,
            child: MenuGridPanel(selectedCategory: _selectedCategory),
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            flex: 2,
            child: CategoryPanel(
              selectedCategory: _selectedCategory,
              onCategorySelected: _onCategorySelected,
            ),
          ),
        ],
      ),
    );
  }
}
