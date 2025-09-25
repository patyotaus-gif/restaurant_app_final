import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // And this one too
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart'; // We'll need this later
class WasteTrackingPage extends StatefulWidget {
  const WasteTrackingPage({super.key});

  @override
  State<WasteTrackingPage> createState() => _WasteTrackingPageState();
}

class _WasteTrackingPageState extends State<WasteTrackingPage> {
  void _showRecordWasteDialog() async {
    // First, fetch all ingredients to show in the dropdown
    final ingredientsSnapshot = await FirebaseFirestore.instance
        .collection('ingredients')
        .get();
    final ingredients = ingredientsSnapshot.docs
        .map((doc) => Ingredient.fromSnapshot(doc))
        .toList();

    Ingredient? selectedIngredient;
    final quantityController = TextEditingController();
    String? selectedReason;
    final formKey = GlobalKey<FormState>();

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Record New Waste'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<Ingredient>(
                    hint: const Text('Select Ingredient'),
                    items: ingredients.map((ing) {
                      return DropdownMenuItem(
                        value: ing,
                        child: Text(ing.name),
                      );
                    }).toList(),
                    onChanged: (value) => selectedIngredient = value,
                    validator: (value) =>
                        value == null ? 'Please select an ingredient' : null,
                  ),
                  TextFormField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity Wasted',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a quantity';
                      }
                      if (double.tryParse(value) == null ||
                          double.parse(value) <= 0) {
                        return 'Please enter a valid positive number';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    hint: const Text('Reason for Waste'),
                    items: ['Expired', 'Damaged', 'Spilled', 'Error', 'Other']
                        .map(
                          (reason) => DropdownMenuItem(
                            value: reason,
                            child: Text(reason),
                          ),
                        )
                        .toList(),
                    onChanged: (value) => selectedReason = value,
                    validator: (value) =>
                        value == null ? 'Please select a reason' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final auth = Provider.of<AuthService>(context, listen: false);
                  final employeeName = auth.currentRole
                      .toString(); // Placeholder

                  FirebaseFirestore.instance.collection('waste_records').add({
                    'ingredientId': selectedIngredient!.id,
                    'ingredientName': selectedIngredient!.name,
                    'quantity': double.parse(quantityController.text),
                    'unit': selectedIngredient!.unit,
                    'reason': selectedReason,
                    'recordedBy': employeeName, // We'll improve this later
                    'timestamp': Timestamp.now(),
                  });
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save Record'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Waste Tracking'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('waste_records')
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No waste recorded yet. Press + to begin.'),
            );
          }

          final records = snapshot.data!.docs;

          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final data = records[index].data() as Map<String, dynamic>;
              final timestamp = (data['timestamp'] as Timestamp).toDate();
              final formattedDate = DateFormat(
                'dd MMM yyyy, HH:mm',
              ).format(timestamp);

              return ListTile(
                title: Text(
                  '${data['ingredientName']}: ${data['quantity']} ${data['unit']}',
                ),
                subtitle: Text('Reason: ${data['reason']}'),
                trailing: Text(
                  formattedDate,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showRecordWasteDialog,
        tooltip: 'Record New Waste',
        child: const Icon(Icons.add),
      ),
    );
  }
}
