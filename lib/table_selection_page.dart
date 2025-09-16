// lib/table_selection_page.dart (updated with square buttons)

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'cart_provider.dart';

class TableSelectionPage extends StatelessWidget {
  const TableSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select a Table'),
        backgroundColor: Colors.indigo,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          // 1. Increased columns to make buttons smaller
          crossAxisCount: 10,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          // 2. Enforce a square aspect ratio for each button
          childAspectRatio: 1 / 1,
        ),
        itemCount: 30, // 30 tables
        itemBuilder: (context, index) {
          final tableNumber = index + 1;
          return ElevatedButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false)
                  .selectDineIn(tableNumber);
              Navigator.of(context).pop();
            },
            // 3. Change the button's shape to be a rounded rectangle
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8), // Less rounded corners
              ),
            ),
            child: Text(
              '$tableNumber',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          );
        },
      ),
    );
  }
}
