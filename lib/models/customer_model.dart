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
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
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
    );
  }
}
