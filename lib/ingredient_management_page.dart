// lib/ingredient_management_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'add_purchase_order_page.dart'; // <-- 1. Add this import
class IngredientManagementPage extends StatefulWidget {
  const IngredientManagementPage({super.key});

  @override
  State<IngredientManagementPage> createState() =>
      _IngredientManagementPageState();
}

class _IngredientManagementPageState extends State<IngredientManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Ingredient> _ingredientsRef;

  @override
  void initState() {
    super.initState();
    _ingredientsRef = _firestore
        .collection('ingredients')
        .withConverter<Ingredient>(
          fromFirestore: Ingredient.fromFirestore,
          toFirestore: (ingredient, _) => ingredient.toFirestore(),
        );
  }

  void _showIngredientDialog({Ingredient? ingredient}) {
    final isNew = ingredient == null;
    final nameController = TextEditingController(text: ingredient?.name);
    final unitController = TextEditingController(text: ingredient?.unit);
    final stockController = TextEditingController(
      text: ingredient?.stockQuantity.toString(),
    );
    final thresholdController = TextEditingController(
      text: ingredient?.lowStockThreshold.toString(),
    );
    final costController = TextEditingController(
      text: ingredient?.cost.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'เพิ่มวัตถุดิบใหม่' : 'แก้ไขวัตถุดิบ'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อวัตถุดิบ',
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'กรุณากรอกชื่อ' : null,
                  ),
                  TextFormField(
                    controller: unitController,
                    decoration: const InputDecoration(
                      labelText: 'หน่วยนับ (เช่น kg, g, ชิ้น)',
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'กรุณากรอกหน่วยนับ' : null,
                  ),
                  TextFormField(
                    controller: stockController,
                    decoration: const InputDecoration(
                      labelText: 'จำนวนในสต็อก',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'กรุณากรอกจำนวน' : null,
                  ),
                  TextFormField(
                    controller: costController,
                    decoration: const InputDecoration(
                      labelText: 'ต้นทุนเฉลี่ยต่อหน่วย (Avg Cost)',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true) ? 'กรุณากรอกต้นทุน' : null,
                  ),
                  TextFormField(
                    controller: thresholdController,
                    decoration: const InputDecoration(
                      labelText: 'จุดแจ้งเตือนสต็อกต่ำ',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? 'กรุณากรอกจุดแจ้งเตือน'
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final dataToSave = Ingredient(
                    id: ingredient?.id ?? '',
                    name: nameController.text,
                    unit: unitController.text,
                    stockQuantity: double.tryParse(stockController.text) ?? 0.0,
                    lowStockThreshold:
                        double.tryParse(thresholdController.text) ?? 0.0,
                    cost: double.tryParse(costController.text) ?? 0.0,
                  );

                  if (isNew) {
                    _ingredientsRef.add(dataToSave);
                  } else {
                    _ingredientsRef
                        .doc(ingredient.id)
                        .update(dataToSave.toFirestore());
                  }
                  Navigator.of(context).pop();
                }
              },
              child: const Text('บันทึก'),
            ),
          ],
        );
      },
    );
  }

  void _deleteIngredient(String docId) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('ยืนยันการลบ'),
          content: const Text('คุณต้องการลบรายการนี้ใช่หรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                _ingredientsRef.doc(docId).delete();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('ลบ'),
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
        title: const Text('จัดการสต็อกวัตถุดิบ'),
        // --- 2. Add this actions section ---
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: 'Add Purchase Order',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const AddPurchaseOrderPage(),
                ),
              );
            },
          ),
        ],
        // ---------------------------------
      ),
      body: StreamBuilder<QuerySnapshot<Ingredient>>(
        stream: _ingredientsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('เกิดข้อผิดพลาด: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('ยังไม่มีวัตถุดิบในระบบ'));
          }

          final ingredients = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredientDoc = ingredients[index];
              final ingredient = ingredientDoc.data();
              final isLowStock =
                  ingredient.stockQuantity <= ingredient.lowStockThreshold;

              return Card(
                color: isLowStock ? Colors.red.withAlpha(25) : null,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(ingredient.name),
                  subtitle: Text(
                    'คงเหลือ: ${ingredient.stockQuantity} ${ingredient.unit} (ต้นทุนเฉลี่ย: ${ingredient.cost.toStringAsFixed(2)})',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showIngredientDialog(ingredient: ingredient),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteIngredient(ingredientDoc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIngredientDialog(),
        tooltip: 'เพิ่มวัตถุดิบใหม่',
        child: const Icon(Icons.add),
      ),
    );
  }
}
