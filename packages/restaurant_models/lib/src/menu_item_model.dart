// lib/models/menu_item_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
class MenuItem {
  final String id;
  final String name;
  final double price;
  final String category;
  final String description;
  final String imageUrl; // 1. Add imageUrl property
  final List<Map<String, dynamic>> recipe;

  MenuItem({
    required this.id,
    required this.name,
    required this.price,
    required this.category,
    required this.description,
    required this.imageUrl, // 2. Add to constructor
    required this.recipe,
  });

  factory MenuItem.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return MenuItem(
      id: doc.id,
      name: data['name'] ?? 'No Name',
      price: (data['price'] as num?)?.toDouble() ?? 0.0,
      category: data['category'] ?? '',
      description: data['description'] ?? '',
      imageUrl: data['imageUrl'] ?? '', // 3. Read from Firestore
      recipe: List<Map<String, dynamic>>.from(data['recipe'] ?? []),
    );
  }
}
