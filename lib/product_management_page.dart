// lib/product_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'models/product_model.dart'; // Use the new Product model

class ProductManagementPage extends StatelessWidget {
  const ProductManagementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Product Management'), // New title
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        // NOTE: We are still using the 'menu_items' collection for now.
        // In a real project, you might migrate this to a 'products' collection.
        stream: FirebaseFirestore.instance
            .collection('menu_items')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No products found.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final product = Product.fromFirestore(
                doc,
              ); // Create a Product object
              return ListTile(
                title: Text(product.name),
                subtitle: Text('${product.price} Baht'),
                trailing: const Icon(Icons.edit),
                onTap: () {
                  // Navigate to the new route, passing the Product object
                  context.push('/admin/products/edit', extra: product);
                },
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to create a new item by passing null
          context.push('/admin/products/edit', extra: null);
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
