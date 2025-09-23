import 'package:cloud_firestore/cloud_firestore.dart';

class GiftCard {
  final String id;
  final String code;
  final double balance;
  final double initialBalance;
  final bool isActive;
  final String? customerId;
  final Timestamp? issuedAt;
  final Timestamp? expiresAt;
  final Timestamp? updatedAt;

  const GiftCard({
    required this.id,
    required this.code,
    required this.balance,
    required this.initialBalance,
    required this.isActive,
    this.customerId,
    this.issuedAt,
    this.expiresAt,
    this.updatedAt,
  });

  factory GiftCard.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return GiftCard(
      id: doc.id,
      code: (data['code'] as String? ?? '').toUpperCase(),
      balance: (data['balance'] as num?)?.toDouble() ?? 0.0,
      initialBalance: (data['initialBalance'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] as bool? ?? true,
      customerId: data['customerId'] as String?,
      issuedAt: data['issuedAt'] as Timestamp?,
      expiresAt: data['expiresAt'] as Timestamp?,
      updatedAt: data['updatedAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'code': code,
      'balance': balance,
      'initialBalance': initialBalance,
      'isActive': isActive,
      if (customerId != null) 'customerId': customerId,
      if (issuedAt != null) 'issuedAt': issuedAt,
      if (expiresAt != null) 'expiresAt': expiresAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }
}
