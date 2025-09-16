// lib/takeaway_orders_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'cart_provider.dart';
import 'models/product_model.dart'; // <-- Import Product

class TakeawayOrdersPage extends StatelessWidget {
  const TakeawayOrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Takeaway Orders'),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/order-type-selection'),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_shopping_cart),
              label: const Text('New Takeaway Order'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: const TextStyle(fontSize: 18),
              ),
              onPressed: () {
                cart.clear();
                cart.selectTakeaway();
                context.push('/dashboard');
              },
            ),
          ),
          const Divider(height: 1),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Text(
              'All Takeaway Orders:',
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .where('orderType', isEqualTo: 'Takeaway')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No takeaway orders found.'));
                }

                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1 / 1,
                  ),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final orderDoc = snapshot.data!.docs[index];
                    final orderData = orderDoc.data()! as Map<String, dynamic>;
                    final orderIdentifier =
                        orderData['orderIdentifier'] ?? 'Takeaway';
                    final total = (orderData['total'] ?? 0).toStringAsFixed(2);
                    final status = orderData['status'] ?? 'new';

                    return ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: status == 'completed'
                            ? Colors.grey.shade500
                            : Colors.deepPurple.shade300,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        cart.clear();
                        final itemsList =
                            (orderData['items'] ?? []) as List<dynamic>;
                        final Map<String, CartItem> loadedItems = {};

                        for (var itemData in itemsList) {
                          // --- FIX: Create a temporary Product and pass it to CartItem ---
                          final tempProduct = Product(
                            id: itemData['id'],
                            name: itemData['name'],
                            price: (itemData['price'] as num).toDouble(),
                            description: itemData['description'] ?? '',
                            imageUrl: itemData['imageUrl'] ?? '',
                            category: itemData['category'] ?? '',
                          );
                          loadedItems[tempProduct.id] = CartItem(
                            product: tempProduct,
                            quantity: itemData['quantity'],
                          );
                        }

                        cart.loadOrder(loadedItems, orderIdentifier);
                        context.push('/dashboard');
                      },
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            orderIdentifier,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$total Baht',
                            style: const TextStyle(fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Chip(
                            label: Text(status.toUpperCase()),
                            backgroundColor: Colors.white24,
                            labelStyle: const TextStyle(color: Colors.white),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
