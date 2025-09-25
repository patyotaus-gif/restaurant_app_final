// lib/models/product_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
// Enum to define the type of product
enum ProductType {
  food, // For restaurant items with recipes
  general, // For standard retail items
  service, // For items that don't have stock, like a service charge
}

class Product {
  final String id;
  final String name;
  final String description;
  final double price;
  final String category;
  final String imageUrl;

  // New fields for flexibility
  final ProductType productType;
  final bool trackStock;
  final String sku;
  final String barcode;
  final double costPrice;
  final String? supplierId;
  final List<Map<String, dynamic>> variations;
  final List<Map<String, dynamic>> recipe;
  final List<String> modifierGroupIds; // <-- ADDED THIS FIELD
  final List<String> kitchenStations;
  final double prepTimeMinutes;

  Product({
    required this.id,
    required this.name,
    this.description = '',
    required this.price,
    required this.category,
    this.imageUrl = '',
    this.productType = ProductType.general,
    this.trackStock = true,
    this.sku = '',
    this.barcode = '',
    this.costPrice = 0.0,
    this.supplierId,
    this.variations = const [],
    this.recipe = const [],
    this.modifierGroupIds = const [], // <-- ADDED TO CONSTRUCTOR
    this.kitchenStations = const [],
    this.prepTimeMinutes = 0,
  });

  factory Product.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Product.fromMap(data, id: doc.id);
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product.fromMap(json, id: json['id'] as String? ?? '');
  }

  static Product fromMap(Map<String, dynamic> data, {required String id}) {
    return Product(
      id: id,
      name: data['name'] ?? 'No Name',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '',
      productType: ProductType.values.firstWhere(
        (e) => e.name == (data['productType'] ?? ProductType.general.name),
      ),
      trackStock: data['trackStock'] ?? true,
      sku: data['sku'] ?? '',
      barcode: data['barcode'] ?? '',
      costPrice: (data['costPrice'] as num?)?.toDouble() ?? 0.0,
      supplierId: data['supplierId'],
      variations: List<Map<String, dynamic>>.from(data['variations'] ?? []),
      recipe: List<Map<String, dynamic>>.from(data['recipe'] ?? []),
      modifierGroupIds: List<String>.from(data['modifierGroupIds'] ?? []),
      kitchenStations: List<String>.from(
        data['kitchenStations'] ?? data['kitchenStationIds'] ?? [],
      ),
      prepTimeMinutes:
          (data['prepTimeMinutes'] as num?)?.toDouble() ??
          (data['prep_time'] as num?)?.toDouble() ??
          0.0,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'category': category,
      'imageUrl': imageUrl,
      'productType': productType.name,
      'trackStock': trackStock,
      'sku': sku,
      'barcode': barcode,
      'costPrice': costPrice,
      'supplierId': supplierId,
      'variations': variations,
      'recipe': recipe,
      'modifierGroupIds':
          modifierGroupIds, // <-- ADDED THIS LINE TO SAVE TO FIRESTORE
      'kitchenStations': kitchenStations,
      'prepTimeMinutes': prepTimeMinutes,
    };
  }

  Map<String, dynamic> toJson() {
    return {'id': id, ...toFirestore()};
  }
}
