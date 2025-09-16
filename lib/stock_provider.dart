// lib/stock_provider.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/ingredient_model.dart';
import 'models/product_model.dart'; // <-- 1. Import Product model

class StockProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Map<String, Ingredient> _ingredients = {};
  StreamSubscription? _stockSubscription;

  StockProvider() {
    fetchAndListenToIngredients();
  }

  Map<String, Ingredient> get ingredients => _ingredients;

  List<Ingredient> get lowStockIngredients {
    if (_ingredients.isEmpty) {
      return [];
    }
    return _ingredients.values
        .where((ing) => ing.stockQuantity <= ing.lowStockThreshold)
        .toList();
  }

  void fetchAndListenToIngredients() {
    _stockSubscription?.cancel();

    _stockSubscription = _firestore
        .collection('ingredients')
        .snapshots()
        .listen(
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

  @override
  void dispose() {
    _stockSubscription?.cancel();
    super.dispose();
  }
}
