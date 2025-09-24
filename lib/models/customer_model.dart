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
  final double storeCreditBalance;
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
  final bool houseAccountEnabled;
  final double houseAccountBalance;
  final double houseAccountCreditLimit;
  final String? billingCompanyName;
  final String? billingAddress;
  final String? billingTaxId;
  final String? billingEmail;
  final String? billingPhone;

  Customer({
    required this.id,
    required this.name,
    required this.phoneNumber,
    required this.loyaltyPoints,
    required this.tier,
    required this.lifetimeSpend,
    required this.notes,
    this.birthDate,
    this.storeCreditBalance = 0,
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
    this.houseAccountEnabled = false,
    this.houseAccountBalance = 0,
    this.houseAccountCreditLimit = 0,
    this.billingCompanyName,
    this.billingAddress,
    this.billingTaxId,
    this.billingEmail,
    this.billingPhone,
  });

  factory Customer.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    final Map<String, dynamic>? rfmData = data['rfm'] as Map<String, dynamic>?;
    final dynamic houseAccountRaw = data['houseAccount'];
    final Map<String, dynamic>? houseAccountData =
        houseAccountRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(houseAccountRaw)
        : null;
    return Customer(
      id: doc.id,
      name: data['name'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      loyaltyPoints: data['loyaltyPoints'] ?? 0,
      tier: data['tier'] ?? 'Silver',
      lifetimeSpend: (data['lifetimeSpend'] as num?)?.toDouble() ?? 0.0,
      notes: data['notes'] ?? '',
      birthDate: data['birthDate'],
      storeCreditBalance:
          (data['storeCredit'] as num?)?.toDouble() ??
          (data['storeCreditBalance'] as num?)?.toDouble() ??
          0.0,
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
      houseAccountEnabled: data['houseAccountEnabled'] == true,
      houseAccountBalance:
          (houseAccountData?['balance'] as num?)?.toDouble() ?? 0.0,
      houseAccountCreditLimit:
          (houseAccountData?['creditLimit'] as num?)?.toDouble() ?? 0.0,
      billingCompanyName: data['billingCompanyName'] as String?,
      billingAddress: data['billingAddress'] as String?,
      billingTaxId: data['billingTaxId'] as String?,
      billingEmail: data['billingEmail'] as String?,
      billingPhone: data['billingPhone'] as String?,
    );
  }

  Customer copyWith({
    String? name,
    String? phoneNumber,
    int? loyaltyPoints,
    String? tier,
    double? lifetimeSpend,
    String? notes,
    Timestamp? birthDate,
    double? storeCreditBalance,
    Map<String, int>? punchCards,
    int? rfmRecencyScore,
    int? rfmFrequencyScore,
    int? rfmMonetaryScore,
    int? rfmTotalScore,
    String? rfmSegment,
    Timestamp? lastOrderAt,
    int? orderCount,
    double? averageOrderValue,
    bool? houseAccountEnabled,
    double? houseAccountBalance,
    double? houseAccountCreditLimit,
    String? billingCompanyName,
    String? billingAddress,
    String? billingTaxId,
    String? billingEmail,
    String? billingPhone,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      loyaltyPoints: loyaltyPoints ?? this.loyaltyPoints,
      tier: tier ?? this.tier,
      lifetimeSpend: lifetimeSpend ?? this.lifetimeSpend,
      notes: notes ?? this.notes,
      birthDate: birthDate ?? this.birthDate,
      storeCreditBalance: storeCreditBalance ?? this.storeCreditBalance,
      punchCards: punchCards ?? this.punchCards,
      rfmRecencyScore: rfmRecencyScore ?? this.rfmRecencyScore,
      rfmFrequencyScore: rfmFrequencyScore ?? this.rfmFrequencyScore,
      rfmMonetaryScore: rfmMonetaryScore ?? this.rfmMonetaryScore,
      rfmTotalScore: rfmTotalScore ?? this.rfmTotalScore,
      rfmSegment: rfmSegment ?? this.rfmSegment,
      lastOrderAt: lastOrderAt ?? this.lastOrderAt,
      orderCount: orderCount ?? this.orderCount,
      averageOrderValue: averageOrderValue ?? this.averageOrderValue,
      houseAccountEnabled: houseAccountEnabled ?? this.houseAccountEnabled,
      houseAccountBalance: houseAccountBalance ?? this.houseAccountBalance,
      houseAccountCreditLimit:
          houseAccountCreditLimit ?? this.houseAccountCreditLimit,
      billingCompanyName: billingCompanyName ?? this.billingCompanyName,
      billingAddress: billingAddress ?? this.billingAddress,
      billingTaxId: billingTaxId ?? this.billingTaxId,
      billingEmail: billingEmail ?? this.billingEmail,
      billingPhone: billingPhone ?? this.billingPhone,
    );
  }
}
