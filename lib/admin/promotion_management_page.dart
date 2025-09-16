import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import '../models/promotion_model.dart';

class PromotionManagementPage extends StatefulWidget {
  const PromotionManagementPage({super.key});

  @override
  State<PromotionManagementPage> createState() =>
      _PromotionManagementPageState();
}

class _PromotionManagementPageState extends State<PromotionManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. ฟังก์ชันสำหรับแสดง Dialog (เพิ่ม/แก้ไข) ---
  void _showPromotionDialog({Promotion? promo}) {
    final isNew = promo == null;
    final codeController = TextEditingController(text: promo?.code);
    final descriptionController = TextEditingController(
      text: promo?.description,
    );
    final valueController = TextEditingController(
      text: promo?.value.toString(),
    );
    String selectedType = promo?.type ?? 'fixed'; // 'fixed' or 'percentage'
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add New Promotion' : 'Edit Promotion'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: codeController,
                    decoration: const InputDecoration(
                      labelText: 'Promotion Code (e.g., SAVE10)',
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'Please enter a code' : null,
                  ),
                  TextFormField(
                    controller: descriptionController,
                    decoration: const InputDecoration(labelText: 'Description'),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'Please enter a description'
                        : null,
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: selectedType,
                    decoration: const InputDecoration(
                      labelText: 'Discount Type',
                    ),
                    items: ['fixed', 'percentage']
                        .map(
                          (type) => DropdownMenuItem(
                            value: type,
                            child: Text(
                              type == 'fixed'
                                  ? 'Fixed Amount (Baht)'
                                  : 'Percentage (%)',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedType = value;
                      }
                    },
                  ),
                  TextFormField(
                    controller: valueController,
                    decoration: const InputDecoration(
                      labelText: 'Discount Value',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,2}'),
                      ),
                    ],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a value';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
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
                  final promoData = {
                    'code': codeController.text
                        .toUpperCase(), // Store code in uppercase for consistency
                    'description': descriptionController.text,
                    'type': selectedType,
                    'value': double.parse(valueController.text),
                    // For new promotions, isActive defaults to false.
                    // For existing ones, its value is not changed here.
                  };

                  if (isNew) {
                    promoData['isActive'] =
                        false; // New promos are inactive by default
                    _firestore.collection('promotions').add(promoData);
                  } else {
                    _firestore
                        .collection('promotions')
                        .doc(promo.id)
                        .update(promoData);
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('Save'),
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
        title: const Text('Promotion Management'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('promotions').orderBy('code').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No promotions found. Press + to add one.'),
            );
          }

          final promotions = snapshot.data!.docs
              .map((doc) => Promotion.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              return ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: Text(
                  promo.code,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(promo.description),
                trailing: Switch(
                  value: promo.isActive,
                  onChanged: (bool value) {
                    _firestore.collection('promotions').doc(promo.id).update({
                      'isActive': value,
                    });
                  },
                ),
                // --- 2. Connect ListTile to the Edit function ---
                onTap: () {
                  _showPromotionDialog(promo: promo);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // --- 3. Connect FAB to the Add function ---
        onPressed: () {
          _showPromotionDialog();
        },
        tooltip: 'Add New Promotion',
        child: const Icon(Icons.add),
      ),
    );
  }
}
