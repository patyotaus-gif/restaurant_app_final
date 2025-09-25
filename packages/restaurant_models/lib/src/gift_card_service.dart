import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'gift_card_model.dart';
class GiftCardService {
  GiftCardService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final _random = Random.secure();

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('giftCards');

  Future<GiftCard?> findByCode(String code) async {
    if (code.isEmpty) return null;
    final normalized = code.toUpperCase().trim();
    final result = await _collection
        .where('code', isEqualTo: normalized)
        .limit(1)
        .get();
    if (result.docs.isEmpty) return null;
    return GiftCard.fromFirestore(result.docs.first);
  }

  Future<GiftCard> createGiftCard({
    required String code,
    required double amount,
    String? customerId,
  }) async {
    final sanitized = amount < 0 ? 0.0 : amount;
    final docRef = _collection.doc();
    final now = Timestamp.now();
    await docRef.set({
      'code': code.toUpperCase(),
      'balance': sanitized,
      'initialBalance': sanitized,
      'isActive': true,
      'customerId': customerId,
      'issuedAt': now,
      'updatedAt': now,
    });
    final snapshot = await docRef.get();
    return GiftCard.fromFirestore(snapshot);
  }

  Future<void> redeemBalance(GiftCard card, double amount) async {
    final sanitized = amount < 0 ? 0.0 : amount;
    await _firestore.runTransaction((transaction) async {
      final docRef = _collection.doc(card.id);
      final snapshot = await transaction.get(docRef);
      if (!snapshot.exists) {
        throw Exception('Gift card not found');
      }
      final data = snapshot.data() as Map<String, dynamic>? ?? {};
      final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
      if (sanitized > balance + 0.001) {
        throw Exception('Insufficient gift card balance');
      }
      transaction.update(docRef, {
        'balance': balance - sanitized,
        'updatedAt': Timestamp.now(),
      });
    });
  }

  Future<GiftCard> issueOrTopUp({
    String? code,
    required double amount,
    String? customerId,
  }) async {
    final sanitized = amount < 0 ? 0.0 : amount;
    if (sanitized == 0) {
      throw Exception('Amount must be greater than zero');
    }

    final normalizedCode = code?.trim().toUpperCase();
    if (normalizedCode != null && normalizedCode.isNotEmpty) {
      final existing = await findByCode(normalizedCode);
      if (existing != null) {
        await _firestore.runTransaction((transaction) async {
          final docRef = _collection.doc(existing.id);
          final snapshot = await transaction.get(docRef);
          final data = snapshot.data() as Map<String, dynamic>? ?? {};
          final balance = (data['balance'] as num?)?.toDouble() ?? 0.0;
          transaction.update(docRef, {
            'balance': balance + sanitized,
            'customerId': data['customerId'] ?? customerId,
            'updatedAt': Timestamp.now(),
          });
        });
        final refreshed = await _collection.doc(existing.id).get();
        return GiftCard.fromFirestore(refreshed);
      }
      return createGiftCard(
        code: normalizedCode,
        amount: sanitized,
        customerId: customerId,
      );
    }

    final generatedCode = _generateCode();
    return createGiftCard(
      code: generatedCode,
      amount: sanitized,
      customerId: customerId,
    );
  }

  String _generateCode({int length = 12}) {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return List.generate(
      length,
      (_) => chars[_random.nextInt(chars.length)],
    ).join();
  }
}
