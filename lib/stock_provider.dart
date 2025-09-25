// lib/stock_provider.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_models/restaurant_models.dart';
class StockProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Ingredient> _ingredients = {};
  StreamSubscription? _stockSubscription;
  String? _activeStoreId;

  StockProvider() {
    fetchAndListenToIngredients();
  }

  Map<String, Ingredient> get ingredients => _ingredients;
  String? get activeStoreId => _activeStoreId;

  List<Ingredient> get lowStockIngredients {
    if (_ingredients.isEmpty) {
      return [];
    }
    return _ingredients.values
        .where((ing) => ing.stockQuantity <= ing.lowStockThreshold)
        .toList();
  }

  void fetchAndListenToIngredients({String? storeId}) {
    _stockSubscription?.cancel();

    Query collectionQuery = _firestore.collection('ingredients');
    if (storeId != null && storeId.isNotEmpty) {
      collectionQuery = collectionQuery.where('storeId', isEqualTo: storeId);
    }

    _stockSubscription = collectionQuery.snapshots().listen(
      (snapshot) {
        Map<String, Ingredient> tempIngredients = {};
        for (var doc in snapshot.docs) {
          final ingredient = Ingredient.fromSnapshot(doc);
          tempIngredients[ingredient.id] = ingredient;
        }
        _ingredients = tempIngredients;
        notifyListeners();
      },
      onError: (error) {
        // Handle error properly in a real app
      },
    );
  }

  void setActiveStore(String? storeId) {
    if (_activeStoreId == storeId) return;
    _activeStoreId = storeId;
    fetchAndListenToIngredients(storeId: storeId);
  }

  Ingredient? getIngredientById(String ingredientId) {
    return _ingredients[ingredientId];
  }

  Ingredient? findByBarcode(String barcode) {
    try {
      return _ingredients.values.firstWhere(
        (ingredient) => ingredient.barcode == barcode,
      );
    } catch (_) {
      return null;
    }
  }

  // --- 2. Change method to accept Product instead of MenuItem ---
  bool isProductAvailable(Product product, {int quantityToCheck = 1}) {
    // For non-food items, we would check the product's own stock level.
    // This part of the logic will be built out later.
    // For now, we focus on the recipe-based stock check for food.
    if (product.productType != ProductType.food || product.recipe.isEmpty) {
      // For now, assume non-food items are always available.
      // We will add direct stock tracking for products later.
      return true;
    }

    for (var recipeIngredient in product.recipe) {
      final String ingredientId = recipeIngredient['ingredientId'];
      final num requiredQtyPerItem = recipeIngredient['quantity'];

      final availableIngredient = _ingredients[ingredientId];

      if (availableIngredient == null) {
        return false;
      }

      if (availableIngredient.stockQuantity <
          (requiredQtyPerItem * quantityToCheck)) {
        return false;
      }
    }
    return true;
  }

  Future<void> deductIngredientsFromUsage(List<dynamic> ingredientUsage) async {
    if (ingredientUsage.isEmpty) return;

    final Map<String, double> aggregated = {};

    for (final entry in ingredientUsage) {
      if (entry is! Map<String, dynamic>) continue;
      final String? ingredientId = entry['ingredientId'] as String?;
      if (ingredientId == null || ingredientId.isEmpty) continue;

      final double quantity = (entry['quantity'] as num?)?.toDouble() ?? 0.0;
      if (quantity == 0) continue;

      aggregated.update(
        ingredientId,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
    }

    if (aggregated.isEmpty) return;

    final batch = _firestore.batch();

    aggregated.forEach((ingredientId, quantity) {
      final docRef = _firestore.collection('ingredients').doc(ingredientId);
      batch.update(docRef, {'stockQuantity': FieldValue.increment(-quantity)});
    });

    await batch.commit();
  }

  Future<void> restockIngredientsFromUsage(
    List<dynamic> ingredientUsage,
  ) async {
    if (ingredientUsage.isEmpty) return;

    final Map<String, double> aggregated = {};

    for (final entry in ingredientUsage) {
      if (entry is! Map<String, dynamic>) continue;
      final String? ingredientId = entry['ingredientId'] as String?;
      if (ingredientId == null || ingredientId.isEmpty) continue;
      final double quantity = (entry['quantity'] as num?)?.toDouble() ?? 0.0;
      if (quantity == 0) continue;

      aggregated.update(
        ingredientId,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
    }

    if (aggregated.isEmpty) return;

    final batch = _firestore.batch();

    aggregated.forEach((ingredientId, quantity) {
      final docRef = _firestore.collection('ingredients').doc(ingredientId);
      batch.update(docRef, {'stockQuantity': FieldValue.increment(quantity)});
    });

    await batch.commit();
  }

  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }
}
