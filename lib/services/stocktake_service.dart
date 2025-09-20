import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/ingredient_model.dart';
import 'audit_log_service.dart';

class StocktakeService {
  StocktakeService(this._firestore, this._auditLogService);

  final FirebaseFirestore _firestore;
  final AuditLogService _auditLogService;

  Future<void> recordStockAdjustment({
    required Ingredient ingredient,
    required double adjustment,
    required String actorId,
    String? storeId,
    String? note,
  }) async {
    final docRef = _firestore.collection('ingredients').doc(ingredient.id);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final currentQuantity =
          (snapshot.data()?['stockQuantity'] as num?)?.toDouble() ?? 0.0;
      final newQuantity = currentQuantity + adjustment;
      transaction.update(docRef, {'stockQuantity': newQuantity});
    });

    await _auditLogService.logEvent(
      type: 'inventory_adjustment',
      description:
          'Adjusted ${ingredient.name} by ${adjustment.toStringAsFixed(2)} ${ingredient.unit}',
      actorId: actorId,
      storeId: storeId,
      metadata: {
        'ingredientId': ingredient.id,
        'adjustment': adjustment,
        'note': note,
      },
    );
  }

  Future<void> recordFullStocktake({
    required Ingredient ingredient,
    required double countedQuantity,
    required String actorId,
    String? storeId,
    String? note,
  }) async {
    final docRef = _firestore.collection('ingredients').doc(ingredient.id);
    double difference = 0;
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(docRef);
      final currentQuantity =
          (snapshot.data()?['stockQuantity'] as num?)?.toDouble() ?? 0.0;
      difference = countedQuantity - currentQuantity;
      transaction.update(docRef, {'stockQuantity': countedQuantity});
    });

    await _auditLogService.logEvent(
      type: 'stocktake',
      description:
          'Stocktake for ${ingredient.name}: counted ${countedQuantity.toStringAsFixed(2)} ${ingredient.unit}',
      actorId: actorId,
      storeId: storeId,
      metadata: {
        'ingredientId': ingredient.id,
        'countedQuantity': countedQuantity,
        'difference': difference,
        'note': note,
      },
    );
  }
}
