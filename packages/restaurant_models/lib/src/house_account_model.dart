// lib/models/house_account_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
class HouseAccount {
  final String id;
  final String tenantId;
  final String? storeId;
  final String customerId;
  final String customerName;
  final String? billingEmail;
  final String? billingPhone;
  final double creditLimit;
  final double currentBalance;
  final int statementDay;
  final int paymentTermsDays;
  final Timestamp? lastStatementGeneratedAt;
  final bool isActive;
  final Map<String, dynamic> metadata;

  const HouseAccount({
    required this.id,
    required this.tenantId,
    required this.customerId,
    required this.customerName,
    this.storeId,
    this.billingEmail,
    this.billingPhone,
    this.creditLimit = 0,
    this.currentBalance = 0,
    this.statementDay = 1,
    this.paymentTermsDays = 30,
    this.lastStatementGeneratedAt,
    this.isActive = true,
    this.metadata = const {},
  });

  factory HouseAccount.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return HouseAccount(
      id: doc.id,
      tenantId: data['tenantId'] as String? ?? 'default',
      storeId: data['storeId'] as String?,
      customerId: data['customerId'] as String? ?? '',
      customerName: data['customerName'] as String? ?? 'House Account Customer',
      billingEmail: data['billingEmail'] as String?,
      billingPhone: data['billingPhone'] as String?,
      creditLimit: (data['creditLimit'] as num?)?.toDouble() ?? 0.0,
      currentBalance: (data['currentBalance'] as num?)?.toDouble() ?? 0.0,
      statementDay: (data['statementDay'] as num?)?.toInt() ?? 1,
      paymentTermsDays: (data['paymentTermsDays'] as num?)?.toInt() ?? 30,
      lastStatementGeneratedAt: data['lastStatementGeneratedAt'] as Timestamp?,
      isActive: data['isActive'] != false,
      metadata: Map<String, dynamic>.from(
        data['metadata'] as Map<String, dynamic>? ?? const {},
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'tenantId': tenantId,
      if (storeId != null) 'storeId': storeId,
      'customerId': customerId,
      'customerName': customerName,
      if (billingEmail != null) 'billingEmail': billingEmail,
      if (billingPhone != null) 'billingPhone': billingPhone,
      'creditLimit': creditLimit,
      'currentBalance': currentBalance,
      'statementDay': statementDay,
      'paymentTermsDays': paymentTermsDays,
      if (lastStatementGeneratedAt != null)
        'lastStatementGeneratedAt': lastStatementGeneratedAt,
      'isActive': isActive,
      if (metadata.isNotEmpty) 'metadata': metadata,
    };
  }

  bool get hasAvailableCredit =>
      creditLimit <= 0 || currentBalance < creditLimit;

  double get availableCredit =>
      creditLimit <= 0 ? double.infinity : creditLimit - currentBalance;

  DateTime calculateDueDate(DateTime reference) {
    return reference.add(Duration(days: paymentTermsDays));
  }

  DateTime calculateStatementAnchor(DateTime reference) {
    final day = statementDay.clamp(1, 28);
    final anchor = DateTime(reference.year, reference.month, day);
    if (reference.isAfter(anchor)) {
      final nextMonth = DateTime(reference.year, reference.month + 1, 1);
      return DateTime(nextMonth.year, nextMonth.month, day);
    }
    return anchor;
  }
}

class HouseAccountChargeSummary {
  final String orderId;
  final String orderIdentifier;
  final double amount;
  final double taxTotal;
  final double subtotal;
  final double discount;
  final double serviceCharge;
  final Timestamp chargedAt;
  final Timestamp dueDate;

  const HouseAccountChargeSummary({
    required this.orderId,
    required this.orderIdentifier,
    required this.amount,
    required this.taxTotal,
    required this.subtotal,
    required this.discount,
    required this.serviceCharge,
    required this.chargedAt,
    required this.dueDate,
  });
}

class MonthlyHouseAccountStatement {
  final HouseAccount account;
  final DateTime periodStart;
  final DateTime periodEnd;
  final double openingBalance;
  final double charges;
  final double payments;
  final List<HouseAccountChargeSummary> chargeDetails;

  const MonthlyHouseAccountStatement({
    required this.account,
    required this.periodStart,
    required this.periodEnd,
    required this.openingBalance,
    required this.charges,
    required this.payments,
    required this.chargeDetails,
  });

  double get closingBalance => openingBalance + charges - payments;
}
