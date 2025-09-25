// lib/models/ingredient_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
class Ingredient {
  final String id;
  final String name;
  final String unit;
  final double stockQuantity;
  final double lowStockThreshold;
  final double cost; // <-- 1. Add cost property
  final String? barcode;
  final String? storeId;

  Ingredient({
    required this.id,
    required this.name,
    required this.unit,
    required this.stockQuantity,
    required this.lowStockThreshold,
    required this.cost, // <-- 2. Add to constructor
    this.barcode,
    this.storeId,
  });

  factory Ingredient.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Ingredient(
      id: doc.id,
      name: data['name'] ?? '',
      unit: data['unit'] ?? '',
      stockQuantity: (data['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold: (data['lowStockThreshold'] as num?)?.toDouble() ?? 0.0,
      cost:
          (data['cost'] as num?)?.toDouble() ??
          0.0, // <-- 3. Read from Firestore
      barcode: data['barcode'] as String?,
      storeId: data['storeId'] as String?,
    );
  }

  factory Ingredient.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
    SnapshotOptions? options,
  ) {
    final data = snapshot.data();
    return Ingredient(
      id: snapshot.id,
      name: data?['name'] ?? '',
      unit: data?['unit'] ?? '',
      stockQuantity: (data?['stockQuantity'] as num?)?.toDouble() ?? 0.0,
      lowStockThreshold:
          (data?['lowStockThreshold'] as num?)?.toDouble() ?? 0.0,
      cost:
          (data?['cost'] as num?)?.toDouble() ??
          0.0, // <-- 4. Read from Firestore
      barcode: data?['barcode'] as String?,
      storeId: data?['storeId'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'unit': unit,
      'stockQuantity': stockQuantity,
      'lowStockThreshold': lowStockThreshold,
      'cost': cost, // <-- 5. Write to Firestore
      if (barcode != null) 'barcode': barcode,
      if (storeId != null) 'storeId': storeId,
    };
  }
}
