// lib/models/customer_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class Customer {
  final String id;
  final String name;
  final String phoneNumber;
  final int loyaltyPoints;
  final String tier;
  final double lifetimeSpend;
  final String notes;
  final Timestamp? birthDate;
  // --- 1. Add new field for punch cards ---
  final Map<String, int> punchCards;
  final int? rfmRecencyScore;
  final int? rfmFrequencyScore;
  final int? rfmMonetaryScore;
  final int? rfmTotalScore;
  final String? rfmSegment;
  final Timestamp? lastOrderAt;
  final int? orderCount;
  final double? averageOrderValue;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.loyaltyPoints,
    required this.tier,
    required this.lifetimeSpend,
    required this.notes,
    this.birthDate,
    this.punchCards =
        const {}, // <-- 2. Add to constructor with a default value
    this.rfmRecencyScore,
    this.rfmFrequencyScore,
    this.rfmMonetaryScore,
    this.rfmTotalScore,
    this.rfmSegment,
    this.lastOrderAt,
    this.orderCount,
    this.averageOrderValue,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final Map<String, dynamic>? rfmData = data['rfm'] as Map<String, dynamic>?;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      loyaltyPoints: data['loyaltyPoints'] ?? 0,
      tier: data['tier'] ?? 'Silver',
      lifetimeSpend: (data['lifetimeSpend'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] ?? '',
      birthDate: data['birthDate'],
      // --- 3. Read from Firestore, handling potential nulls ---
      punchCards: Map<String, int>.from(data['punchCards'] ?? {}),
      rfmRecencyScore: (rfmData?['recencyScore'] as num?)?.toInt(),
      rfmFrequencyScore: (rfmData?['frequencyScore'] as num?)?.toInt(),
      rfmMonetaryScore: (rfmData?['monetaryScore'] as num?)?.toInt(),
      rfmTotalScore: (rfmData?['totalScore'] as num?)?.toInt(),
      rfmSegment: rfmData?['segment'] as String?,
      lastOrderAt: rfmData?['lastOrderAt'] as Timestamp?,
      orderCount: (rfmData?['orderCount'] as num?)?.toInt(),
      averageOrderValue: (rfmData?['averageOrderValue'] as num?)?.toDouble(),
    );
  }
}
