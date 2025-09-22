// lib/widgets/order_dashboard/menu_grid_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../cart_provider.dart';
import '../../stock_provider.dart';
import '../../models/product_model.dart';
import '../../services/menu_cache_provider.dart';
import '../modifier_selection_dialog.dart'; // <-- 1. IMPORT THE DIALOG

class MenuGridPanel extends StatelessWidget {
  final String selectedCategory;

  const MenuGridPanel({super.key, required this.selectedCategory});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu Items'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<MenuCacheProvider>(
        builder: (context, menuCache, child) {
          final items = menuCache
              .productsByCategory(selectedCategory)
              .toList(growable: false);
          if (!menuCache.isReady) {
            return const Center(child: CircularProgressIndicator());
          }
          if (items.isEmpty) {
            return const Center(child: Text('No items in this category.'));
          }

          return GridView.builder(
            padding: const EdgeInsets.all(12.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
            ),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final product = items[index];

              return Consumer2<CartProvider, StockProvider>(
                builder: (context, cart, stock, child) {
                  final int quantityInCart = cart.items.values
                      .where((item) => item.product.id == product.id)
                      .fold(0, (sum, item) => sum + item.quantity);

                  final bool isAvailable = stock.isProductAvailable(
                    product,
                    quantityToCheck: quantityInCart + 1,
                  );

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      foregroundColor: Colors.black87,
                      backgroundColor: isAvailable
                          ? Colors.white
                          : Colors.grey.shade300,
                      shadowColor: Colors.grey.shade300,
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
                    ),

                    // --- 2. THIS IS THE MAIN LOGIC CHANGE ---
                    onPressed: isAvailable
                        ? () async {
                            if (product.modifierGroupIds.isNotEmpty) {
                              final selectedModifiers =
                                  await showDialog<List<Map<String, dynamic>>>(
                                    context: context,
                                    builder: (ctx) => ModifierSelectionDialog(
                                      product: product,
                                    ),
                                  );

                              if (selectedModifiers != null) {
                                cart.addItem(
                                  product,
                                  modifiers: selectedModifiers,
                                );
                              }
                            } else {
                              cart.addItem(product);
                            }
                          }
                        : null,

                    // ---------------------------------------------
                    child: Stack(
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: Center(
                                child: Text(
                                  product.name,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4.0),
                              child: Text(
                                '${product.price.toStringAsFixed(2)} บาท',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.grey.shade800,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!isAvailable)
                          Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'สินค้าหมด',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
