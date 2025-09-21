import 'package:cloud_firestore/cloud_firestore.dart';

class KitchenStation {
  const KitchenStation({
    required this.id,
    required this.name,
    this.categories = const [],
    this.productIds = const [],
    this.allowUnassigned = false,
    this.displayOrder = 0,
  });

  factory KitchenStation.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return KitchenStation(
      id: doc.id,
      name: data['name'] as String? ?? 'Station',
      categories: List<String>.from(data['categories'] ?? const []),
      productIds: List<String>.from(
        data['productIds'] ?? data['products'] ?? const [],
      ),
      allowUnassigned: data['allowUnassigned'] as bool? ?? false,
      displayOrder: (data['displayOrder'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String name;
  final List<String> categories;
  final List<String> productIds;
  final bool allowUnassigned;
  final int displayOrder;

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'categories': categories,
      'productIds': productIds,
      'allowUnassigned': allowUnassigned,
      'displayOrder': displayOrder,
    };
  }

  bool matchesItem(Map<String, dynamic> item) {
    final itemCategory = item['category'] as String? ?? '';
    final itemId = item['id'] as String? ?? '';
    if (productIds.contains(itemId)) {
      return true;
    }
    if (categories.contains(itemCategory)) {
      return true;
    }
    return allowUnassigned && productIds.isEmpty && categories.isEmpty;
  }
}
