// lib/add_purchase_order_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/ingredient_model.dart';

// Helper class for a line item in the PO
class PurchaseOrderItem {
  Ingredient ingredient;
  TextEditingController quantityController = TextEditingController();
  TextEditingController costController = TextEditingController();

  PurchaseOrderItem({required this.ingredient});
}

class AddPurchaseOrderPage extends StatefulWidget {
  const AddPurchaseOrderPage({super.key});

  @override
  State<AddPurchaseOrderPage> createState() => _AddPurchaseOrderPageState();
}

class _AddPurchaseOrderPageState extends State<AddPurchaseOrderPage> {
  final _supplierController = TextEditingController();
  final List<PurchaseOrderItem> _poItems = [];
  bool _isLoading = false;

  @override
  void dispose() {
    _supplierController.dispose();
    for (var item in _poItems) {
      item.quantityController.dispose();
      item.costController.dispose();
    }
    super.dispose();
  }

  void _addIngredientToPO() async {
    // In a real app, you might have a dedicated search page.
    // For now, we'll show a dialog with all ingredients.
    final allIngredients = await FirebaseFirestore.instance
        .collection('ingredients')
        .get();
    final ingredientsList = allIngredients.docs
        .map((doc) => Ingredient.fromSnapshot(doc))
        .toList();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Ingredient'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: ingredientsList.length,
            itemBuilder: (context, index) {
              final ingredient = ingredientsList[index];
              return ListTile(
                title: Text(ingredient.name),
                onTap: () {
                  setState(() {
                    // Avoid adding duplicates
                    if (!_poItems.any(
                      (item) => item.ingredient.id == ingredient.id,
                    )) {
                      _poItems.add(PurchaseOrderItem(ingredient: ingredient));
                    }
                  });
                  Navigator.of(ctx).pop();
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _removePoItem(int index) {
    setState(() {
      _poItems.removeAt(index);
    });
  }

  Future<void> _savePurchaseOrder() async {
    if (_supplierController.text.isEmpty || _poItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // <-- FIXED
          content: Text('Please fill in supplier and add at least one item.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final itemsToSave = [];
    double totalAmount = 0;

    for (var item in _poItems) {
      final quantity = double.tryParse(item.quantityController.text) ?? 0;
      final cost = double.tryParse(item.costController.text) ?? 0;
      if (quantity <= 0 || cost <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // <-- FIXED
            content: Text(
              'Please enter valid quantity and cost for all items.',
            ),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _isLoading = false;
        });
        return;
      }
      itemsToSave.add({
        'ingredientId': item.ingredient.id,
        'ingredientName': item.ingredient.name,
        'quantity': quantity,
        'cost': cost,
      });
      totalAmount += cost;
    }

    try {
      await FirebaseFirestore.instance.collection('purchase_orders').add({
        'supplier': _supplierController.text,
        'timestamp': Timestamp.now(),
        'totalAmount': totalAmount,
        'items': itemsToSave,
        'status': 'completed', // Status for received goods
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            // <-- FIXED
            content: Text('Purchase Order saved successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            // <-- FIXED
            content: Text('Failed to save PO: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Purchase Order'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _isLoading ? null : _savePurchaseOrder,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _supplierController,
              decoration: const InputDecoration(
                labelText: 'Supplier Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _poItems.length,
                itemBuilder: (context, index) {
                  final poItem = _poItems[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                poItem.ingredient.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                ),
                                onPressed: () => _removePoItem(index),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: poItem.quantityController,
                                  decoration: InputDecoration(
                                    labelText:
                                        'Quantity (${poItem.ingredient.unit})',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextField(
                                  controller: poItem.costController,
                                  decoration: const InputDecoration(
                                    labelText: 'Total Cost (Baht)',
                                  ),
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Add Ingredient'),
        onPressed: _addIngredientToPO,
      ),
    );
  }
}
