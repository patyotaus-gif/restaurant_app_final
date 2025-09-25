import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart'; // <-- 1. Add this import
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../stock_provider.dart';
class LowStockAlertPage extends StatelessWidget {
  const LowStockAlertPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Alerts'),
        backgroundColor: Colors.red.shade700,
      ),
      body: Consumer<StockProvider>(
        builder: (context, stockProvider, child) {
          final lowStockItems = stockProvider.lowStockIngredients;

          if (lowStockItems.isEmpty) {
            return const Center(
              child: Text(
                'All items are well-stocked!',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: lowStockItems.length,
            itemBuilder: (context, index) {
              final Ingredient item = lowStockItems[index];
              return ListTile(
                leading: const Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.orange,
                ),
                title: Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  'Threshold: ${item.lowStockThreshold} ${item.unit}',
                ),
                trailing: Text(
                  'Remaining: ${item.stockQuantity} ${item.unit}',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // --- 2. Add this onTap function ---
                onTap: () {
                  context.push('/admin/inventory');
                },
                // ---------------------------------
              );
            },
          );
        },
      ),
    );
  }
}
