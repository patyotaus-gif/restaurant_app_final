import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

import '../models/fx_rate.dart';

class FxRateService {
  FxRateService(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('fxRates');

  Future<Map<String, double>> loadRates({
    required String baseCurrency,
    DateTime? asOf,
  }) async {
    final targetDate = asOf ?? DateTime.now();
    final docId = DateFormat('yyyy-MM-dd').format(targetDate);
    final doc = await _collection.doc(docId).get();
    if (!doc.exists) {
      return {};
    }
    final data = doc.data();
    if (data == null) {
      return {};
    }
    final storedBase = (data['base'] as String? ?? '').toUpperCase();
    if (storedBase.isNotEmpty && storedBase != baseCurrency.toUpperCase()) {
      return {};
    }
    final rates = Map<String, dynamic>.from(data['rates'] ?? const {});
    return rates.map((key, value) => MapEntry(
          key.toUpperCase(),
          (value as num).toDouble(),
        ));
  }

  Stream<Map<String, double>> watchRates({
    required String baseCurrency,
    DateTime? asOf,
  }) {
    final targetDate = asOf ?? DateTime.now();
    final docId = DateFormat('yyyy-MM-dd').format(targetDate);
    return _collection.doc(docId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        return {};
      }
      final data = snapshot.data();
      if (data == null) {
        return {};
      }
      final storedBase = (data['base'] as String? ?? '').toUpperCase();
      if (storedBase.isNotEmpty && storedBase != baseCurrency.toUpperCase()) {
        return {};
      }
      final rates = Map<String, dynamic>.from(data['rates'] ?? const {});
      return rates.map((key, value) => MapEntry(
            key.toUpperCase(),
            (value as num).toDouble(),
          ));
    });
  }

  Future<void> upsertRate({
    required FxRate rate,
  }) async {
    final docId = DateFormat('yyyy-MM-dd').format(rate.asOf);
    final docRef = _collection.doc(docId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final baseCurrency = rate.baseCurrency.toUpperCase();
      final quoteCurrency = rate.quoteCurrency.toUpperCase();
      Map<String, dynamic> updatedData = {
        'base': baseCurrency,
        'rates': {quoteCurrency: rate.rate},
      };
      if (snapshot.exists) {
        final data = snapshot.data();
        if (data != null) {
          final existingRates = Map<String, dynamic>.from(
            data['rates'] as Map<String, dynamic>? ?? const {},
          );
          existingRates[quoteCurrency] = rate.rate;
          updatedData = {
            'base': baseCurrency,
            'rates': existingRates,
          };
        }
      }
      transaction.set(docRef, updatedData, SetOptions(merge: true));
    });
  }
}
