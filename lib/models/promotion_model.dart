import 'package:cloud_firestore/cloud_firestore.dart';

class Promotion {
  final String id;
  final String code;
  final String description;
  final String type; // 'fixed' or 'percentage'
  final double value;
  final bool isActive;

  Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    required this.isActive,
  });

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      code: data['code'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'fixed',
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'code': code,
      'description': description,
      'type': type,
      'value': value,
      'isActive': isActive,
    };
  }
}
