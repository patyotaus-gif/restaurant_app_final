// lib/models/punch_card_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class PunchCardCampaign {
  final String id;
  final String name;
  final String description;
  final int goal; // e.g., 10 stamps
  final String rewardDescription; // e.g., "Free Coffee"
  final List<String>
  applicableCategories; // e.g., ['hot_drinks', 'soft_drinks']
  final bool isActive;

  PunchCardCampaign({
    required this.id,
    required this.name,
    required this.description,
    required this.goal,
    required this.rewardDescription,
    required this.applicableCategories,
    required this.isActive,
  });

  factory PunchCardCampaign.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PunchCardCampaign(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      goal: data['goal'] ?? 10,
      rewardDescription: data['rewardDescription'] ?? '',
      applicableCategories: List<String>.from(
        data['applicableCategories'] ?? [],
      ),
      isActive: data['isActive'] ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'goal': goal,
      'rewardDescription': rewardDescription,
      'applicableCategories': applicableCategories,
      'isActive': isActive,
    };
  }
}
