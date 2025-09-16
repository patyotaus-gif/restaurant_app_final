// lib/admin/create_purchase_order_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import '../models/supplier_model.dart';
import '../models/ingredient_model.dart'; // <-- Use Ingredient model
import '../models/purchase_order_model.dart';

class CreatePurchaseOrderPage extends StatefulWidget {
  const CreatePurchaseOrderPage({super.key});

  @override
  State<CreatePurchaseOrderPage> createState() =>
      _CreatePurchaseOrderPageState();
}

class _CreatePurchaseOrderPageState extends State<CreatePurchaseOrderPage> {
  Supplier? _selectedSupplier;
  final List<PurchaseOrderItem> _items = [];
  bool _isLoading = false;

  void _addItemToPo() async {
    final ingredientsSnapshot = await FirebaseFirestore.instance
        .collection('ingredients')
        .get();
    final ingredients = ingredientsSnapshot.docs
        .map((doc) => Ingredient.fromSnapshot(doc))
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        Ingredient? selectedIngredient;
        final qtyController = TextEditingController();
        final costController = TextEditingController();

        return AlertDialog(
          title: const Text('Add Ingredient to PO'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<Ingredient>(
                hint: const Text('Select Ingredient'),
                items: ingredients
                    .map((i) => DropdownMenuItem(value: i, child: Text(i.name)))
                    .toList(),
                onChanged: (val) => selectedIngredient = val,
              ),
              TextFormField(
                controller: qtyController,
                decoration: const InputDecoration(labelText: 'Quantity'),
                keyboardType: TextInputType.number,
              ),
              TextFormField(
                controller: costController,
                decoration: const InputDecoration(
                  labelText: 'Total Cost for this line',
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (selectedIngredient != null &&
                    qtyController.text.isNotEmpty &&
                    costController.text.isNotEmpty) {
                  setState(() {
                    _items.add(
                      PurchaseOrderItem(
                        productId: selectedIngredient!
                            .id, // Still use productId field for consistency
                        productName: selectedIngredient!.name,
                        quantity: double.parse(qtyController.text),
                        cost: double.parse(costController.text),
                      ),
                    );
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _savePo() async {
    if (_selectedSupplier == null || _items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a supplier and add at least one item.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final totalAmount = _items.fold(0.0, (sum, item) => sum + item.cost);

    final newPo = {
      'poNumber': 'PO-${DateTime.now().millisecondsSinceEpoch}',
      'supplierId': _selectedSupplier!.id,
      'supplierName': _selectedSupplier!.name,
      'items': _items.map((item) => item.toMap()).toList(),
      'status': PoStatus.ordered.name,
      'orderDate': Timestamp.now(),
      'totalAmount': totalAmount,
    };

    await FirebaseFirestore.instance.collection('purchase_orders').add(newPo);

    if (mounted) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Purchase Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePo,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('suppliers')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const CircularProgressIndicator();
                final suppliers = snapshot.data!.docs
                    .map((doc) => Supplier.fromFirestore(doc))
                    .toList();
                return DropdownButtonFormField<Supplier>(
                  hint: const Text('Select Supplier'),
                  value: _selectedSupplier,
                  items: suppliers
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedSupplier = val),
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            const Divider(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: _items.length,
                itemBuilder: (context, index) {
                  final item = _items[index];
                  return ListTile(
                    title: Text(item.productName),
                    subtitle: Text('Qty: ${item.quantity}'),
                    trailing: Text('${item.cost.toStringAsFixed(2)} Baht'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItemToPo,
        label: const Text('Add Item'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
