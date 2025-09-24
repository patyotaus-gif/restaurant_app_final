// lib/services/house_account_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/house_account_model.dart';

class HouseAccountService {
  HouseAccountService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<HouseAccount>> watchAccounts({
    required String tenantId,
    String? storeId,
  }) {
    Query collection = _firestore
        .collection('houseAccounts')
        .where('tenantId', isEqualTo: tenantId);
    if (storeId != null) {
      collection = collection.where('storeId', isEqualTo: storeId);
    }
    collection = collection.where('isActive', isEqualTo: true);

    return collection.snapshots().map(
      (snapshot) => snapshot.docs.map(HouseAccount.fromFirestore).toList(),
    );
  }

  Future<void> recordCharge({
    required HouseAccount account,
    required String orderId,
    required String orderIdentifier,
    required double amount,
    required double subtotal,
    required double discount,
    required double serviceCharge,
    required Map<String, dynamic> taxSummary,
    required DateTime chargedAt,
    DateTime? dueDate,
  }) async {
    final resolvedDueDate = dueDate ?? account.calculateDueDate(chargedAt);
    final statementAnchor = account.calculateStatementAnchor(chargedAt);
    final statementKey =
        '${statementAnchor.year}-${statementAnchor.month.toString().padLeft(2, '0')}';

    final chargeData = {
      'orderId': orderId,
      'orderIdentifier': orderIdentifier,
      'amount': amount,
      'subtotal': subtotal,
      'discount': discount,
      'serviceCharge': serviceCharge,
      'tax': taxSummary,
      'chargedAt': Timestamp.fromDate(chargedAt),
      'dueDate': Timestamp.fromDate(resolvedDueDate),
      'statementMonth': statementKey,
      'status': 'open',
    };

    final accountRef = _firestore.collection('houseAccounts').doc(account.id);
    final chargeRef = accountRef.collection('charges').doc(orderId);

    await _firestore.runTransaction((transaction) async {
      transaction.set(chargeRef, chargeData, SetOptions(merge: true));
      transaction.set(accountRef, {
        'currentBalance': FieldValue.increment(amount),
        'lastChargedAt': Timestamp.fromDate(chargedAt),
      }, SetOptions(merge: true));
    });
  }

  Future<MonthlyHouseAccountStatement> buildMonthlyStatement({
    required HouseAccount account,
    required DateTime period,
  }) async {
    final monthKey =
        '${period.year}-${period.month.toString().padLeft(2, '0')}';
    final chargesSnapshot = await _firestore
        .collection('houseAccounts')
        .doc(account.id)
        .collection('charges')
        .where('statementMonth', isEqualTo: monthKey)
        .get();

    final charges = chargesSnapshot.docs.map((doc) {
      final data = doc.data();
      final Map<String, dynamic>? taxData = data['tax'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(data['tax'] as Map<String, dynamic>)
          : null;
      return HouseAccountChargeSummary(
        orderId: data['orderId'] as String? ?? doc.id,
        orderIdentifier: data['orderIdentifier'] as String? ?? doc.id,
        amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
        taxTotal: (taxData?['total'] as num?)?.toDouble() ?? 0.0,
        subtotal: (data['subtotal'] as num?)?.toDouble() ?? 0.0,
        discount: (data['discount'] as num?)?.toDouble() ?? 0.0,
        serviceCharge: (data['serviceCharge'] as num?)?.toDouble() ?? 0.0,
        chargedAt: data['chargedAt'] as Timestamp? ?? Timestamp.now(),
        dueDate: data['dueDate'] as Timestamp? ?? Timestamp.now(),
      );
    }).toList();

    final totalCharges = charges.fold<double>(
      0,
      (sum, charge) => sum + charge.amount,
    );

    // Payments can be stored under a "payments" subcollection if implemented later.
    final paymentsSnapshot = await _firestore
        .collection('houseAccounts')
        .doc(account.id)
        .collection('payments')
        .where('statementMonth', isEqualTo: monthKey)
        .get();

    final payments = paymentsSnapshot.docs.fold<double>(
      0,
      (sum, doc) => sum + ((doc.data()['amount'] as num?)?.toDouble() ?? 0.0),
    );

    final periodStart = DateTime(period.year, period.month, 1);
    final periodEnd = DateTime(period.year, period.month + 1, 0, 23, 59, 59);

    return MonthlyHouseAccountStatement(
      account: account,
      periodStart: periodStart,
      periodEnd: periodEnd,
      openingBalance: account.currentBalance - totalCharges + payments,
      charges: totalCharges,
      payments: payments,
      chargeDetails: charges,
    );
  }
}
