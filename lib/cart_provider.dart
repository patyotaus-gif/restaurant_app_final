// lib/cart_provider.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'stock_provider.dart';
import 'models/product_model.dart';
import 'models/promotion_model.dart';
import 'models/customer_model.dart';
import 'models/punch_card_model.dart';

enum OrderType { dineIn, takeaway, retail }

class CartItem {
  final Product product;
  int quantity;
  final List<Map<String, dynamic>> selectedModifiers;

  CartItem({
    required this.product,
    this.quantity = 1,
    this.selectedModifiers = const [],
  });

  String get id => product.id;
  String get name => product.name;
  double get price => product.price;
  String get description => product.description;
  String get imageUrl => product.imageUrl;
  List<Map<String, dynamic>> get recipe => product.recipe;
  String get category => product.category;

  double get modifiersPrice {
    if (selectedModifiers.isEmpty) return 0.0;
    return selectedModifiers.fold(
      0.0,
      (sum, modifier) => sum + (modifier['priceChange'] as num),
    );
  }

  double get priceWithModifiers => price + modifiersPrice;
}

class CartProvider with ChangeNotifier {
  Map<String, CartItem> _items = {};
  OrderType? _orderType;
  String? _orderIdentifier;
  StockProvider? _stockProvider;
  Customer? _customer;
  double _discount = 0.0;
  String _discountType = 'none';
  Promotion? _appliedPromotion;
  bool _serviceChargeEnabled = false;
  double _serviceChargeRate = 0.10; // default 10%
  double _tipAmount = 0.0;
  int _splitCount = 1;

  Map<String, CartItem> get items => {..._items};
  OrderType? get orderType => _orderType;
  String? get orderIdentifier => _orderIdentifier;
  int get itemCount => _items.length;
  Customer? get customer => _customer;
  double get discount => _discount;
  String get discountType => _discountType;
  Promotion? get appliedPromotion => _appliedPromotion;
  bool get serviceChargeEnabled => _serviceChargeEnabled;
  double get serviceChargeRate => _serviceChargeRate;
  double get tipAmount => _tipAmount;
  int get splitCount => _splitCount;
  Set<String> get categoriesInCart =>
      _items.values.map((item) => item.category).toSet();

  double get splitAmountPerGuest {
    final normalizedCount = _splitCount <= 0 ? 1 : _splitCount;
    return normalizedCount == 0 ? totalAmount : totalAmount / normalizedCount;
  }

  bool get isCustomerBirthdayMonth {
    if (_customer == null || _customer!.birthDate == null) {
      return false;
    }
    final now = DateTime.now();
    final birthDate = _customer!.birthDate!.toDate();
    return now.month == birthDate.month;
  }

  double get subtotal {
    var total = 0.0;
    _items.forEach((key, cartItem) {
      total += cartItem.priceWithModifiers * cartItem.quantity;
    });
    return total;
  }

  double get serviceChargeAmount {
    if (!_serviceChargeEnabled) return 0.0;
    final base = subtotal - _discount;
    final baseNonNegative = base < 0 ? 0 : base;
    return baseNonNegative * _serviceChargeRate;
  }

  double get totalAmount {
    final base = subtotal - _discount;
    final baseNonNegative = base < 0 ? 0 : base;
    return baseNonNegative + serviceChargeAmount + _tipAmount;
  }

  int get totalQuantity {
    var total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.quantity;
    });
    return total;
  }

  List<Map<String, dynamic>> get ingredientUsage {
    final Map<String, Map<String, dynamic>> aggregatedUsage = {};

    for (final cartItem in _items.values) {
      if (cartItem.recipe.isEmpty) continue;

      for (final recipeEntry in cartItem.recipe) {
        if (recipeEntry is! Map<String, dynamic>) {
          continue;
        }
        final ingredientId = recipeEntry['ingredientId'] as String?;
        if (ingredientId == null || ingredientId.isEmpty) {
          continue;
        }

        final perUnitQuantity =
            (recipeEntry['quantity'] as num?)?.toDouble() ?? 0.0;
        if (perUnitQuantity <= 0) {
          continue;
        }

        final totalQuantity = perUnitQuantity * cartItem.quantity;
        final ingredientName =
            recipeEntry['ingredientName'] ?? recipeEntry['name'] ?? '';
        final unit = recipeEntry['unit'] ?? recipeEntry['ingredientUnit'] ?? '';

        aggregatedUsage.update(
          ingredientId,
          (existing) {
            final currentQuantity =
                (existing['quantity'] as num?)?.toDouble() ?? 0.0;
            return {
              'ingredientId': ingredientId,
              'ingredientName': existing['ingredientName'] ?? ingredientName,
              'unit': existing['unit'] ?? unit,
              'quantity': currentQuantity + totalQuantity,
            };
          },
          ifAbsent: () => {
            'ingredientId': ingredientId,
            'ingredientName': ingredientName,
            'unit': unit,
            'quantity': totalQuantity,
          },
        );
      }
    }

    return aggregatedUsage.values
        .map(
          (entry) => {
            'ingredientId': entry['ingredientId'],
            'ingredientName': entry['ingredientName'],
            'unit': entry['unit'],
            'quantity': (entry['quantity'] as num?)?.toDouble() ?? 0.0,
          },
        )
        .toList();
  }

  void update(StockProvider stock) {
    _stockProvider = stock;
  }

  void setCustomer(DocumentSnapshot? customerDoc) {
    final previousCustomerId = _customer?.id;

    if (customerDoc == null) {
      _customer = null;
    } else {
      _customer = Customer.fromFirestore(customerDoc);
    }

    if (previousCustomerId != _customer?.id) {
      _discount = 0.0;
      _discountType = 'none';
      _appliedPromotion = null;
    }
    notifyListeners();
  }

  Future<String> applyPromotionCode(String code) async {
    if (code.isEmpty) return "Please enter a code.";
    if (_discountType != 'none') return "A discount has already been applied.";

    final codeUpperCase = code.toUpperCase();
    final promoQuery = await FirebaseFirestore.instance
        .collection('promotions')
        .where('code', isEqualTo: codeUpperCase)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (promoQuery.docs.isEmpty) return "Invalid or inactive promotion code.";

    final promo = Promotion.fromFirestore(promoQuery.docs.first);
    final validationMessage = promo.rules.validate(
      subtotal: subtotal,
      itemCount: totalQuantity,
      categories: categoriesInCart,
      orderType: _orderType?.name,
      currentTime: DateTime.now(),
    );

    if (validationMessage != null) {
      return validationMessage;
    }

    double calculatedDiscount = 0;

    if (promo.type == 'percentage') {
      calculatedDiscount = subtotal * (promo.value / 100);
    } else {
      calculatedDiscount = promo.value;
    }

    _discount = (subtotal < calculatedDiscount) ? subtotal : calculatedDiscount;
    _discountType = 'promotion';
    _appliedPromotion = promo;
    notifyListeners();
    return "Promotion '${promo.code}' applied successfully!";
  }

  // --- ADDED THIS FUNCTION BACK ---
  void applyPointsDiscount() {
    if (_customer == null) return;
    removeDiscount();
    final points = _customer!.loyaltyPoints;
    final maxDiscountFromPoints = (points / 10).floor().toDouble();
    final applicableDiscount = maxDiscountFromPoints > subtotal
        ? subtotal
        : maxDiscountFromPoints;
    _discount = applicableDiscount;
    _discountType = 'points';
    notifyListeners();
  }

  // --- ADDED THIS FUNCTION BACK ---
  void applyBirthdayDiscount({double percentage = 15.0}) {
    if (_discountType != 'none') return;

    _discount = subtotal * (percentage / 100);
    _discountType = 'promotion';
    _appliedPromotion = Promotion(
      id: 'birthday',
      code: 'BIRTHDAY',
      description: 'Happy Birthday! $percentage% Off',
      type: 'percentage',
      value: percentage,
      isActive: true,
      rules: const PromotionRules(),
    );
    notifyListeners();
  }

  Future<String> redeemPunchCardReward(PunchCardCampaign campaign) async {
    if (_discountType != 'none')
      return "Cannot redeem reward while another discount is active.";
    if (_customer == null) return "No customer selected.";

    CartItem? itemToDiscount;
    for (final item in _items.values) {
      if (campaign.applicableCategories.contains(item.category)) {
        if (itemToDiscount == null || item.price < itemToDiscount.price) {
          itemToDiscount = item;
        }
      }
    }

    if (itemToDiscount == null) {
      return "No eligible items in the cart for this reward.";
    }

    _discount = itemToDiscount.price;
    _discountType = 'promotion';
    _appliedPromotion = Promotion(
      id: campaign.id,
      code: 'PUNCHCARD',
      description: campaign.rewardDescription,
      type: 'fixed',
      value: itemToDiscount.price,
      isActive: true,
      rules: const PromotionRules(),
    );

    final customerRef = FirebaseFirestore.instance
        .collection('customers')
        .doc(_customer!.id);
    await customerRef.update({'punchCards.${campaign.id}': 0});

    _customer!.punchCards[campaign.id] = 0;

    notifyListeners();
    return "${campaign.rewardDescription} redeemed successfully!";
  }

  void removeDiscount() {
    _discount = 0.0;
    _discountType = 'none';
    _appliedPromotion = null;
    notifyListeners();
  }

  void setServiceChargeEnabled(bool value) {
    if (_serviceChargeEnabled == value) return;
    _serviceChargeEnabled = value;
    notifyListeners();
  }

  void setServiceChargeRate(double rate) {
    final normalizedRate = rate.clamp(0.0, 1.0);
    final normalizedDouble = normalizedRate is double
        ? normalizedRate
        : (normalizedRate as num).toDouble();
    if (_serviceChargeRate == normalizedDouble) return;
    _serviceChargeRate = normalizedDouble;
    notifyListeners();
  }

  void setTipAmount(double amount) {
    final double sanitizedAmount = amount < 0 ? 0.0 : amount;
    if (_tipAmount == sanitizedAmount) return;
    _tipAmount = sanitizedAmount;
    notifyListeners();
  }

  void setSplitCount(int count) {
    final sanitized = count < 1 ? 1 : count;
    if (_splitCount == sanitized) return;
    _splitCount = sanitized;
    notifyListeners();
  }

  void incrementSplitCount() {
    setSplitCount(_splitCount + 1);
  }

  void decrementSplitCount() {
    if (_splitCount <= 1) return;
    setSplitCount(_splitCount - 1);
  }

  void clear() {
    _items = {};
    _orderType = null;
    _orderIdentifier = null;
    _customer = null;
    _serviceChargeEnabled = false;
    _serviceChargeRate = 0.10;
    _tipAmount = 0.0;
    _splitCount = 1;
    removeDiscount();
    notifyListeners();
  }

  bool addItem(Product product, {List<Map<String, dynamic>>? modifiers}) {
    if (_stockProvider == null) return false;

    final modifiersKey =
        modifiers
            ?.map((m) => '${m['groupName']}:${m['optionName']}')
            .join('_') ??
        '';
    final itemKey = '${product.id}_$modifiersKey';

    final int currentQuantityInCart = _items[itemKey]?.quantity ?? 0;
    if (!_stockProvider!.isProductAvailable(
      product,
      quantityToCheck: currentQuantityInCart + 1,
    )) {
      return false;
    }

    if (_items.containsKey(itemKey)) {
      _items.update(itemKey, (existing) {
        existing.quantity++;
        return existing;
      });
    } else {
      _items.putIfAbsent(
        itemKey,
        () => CartItem(
          product: product,
          quantity: 1,
          selectedModifiers: modifiers ?? [],
        ),
      );
    }
    notifyListeners();
    return true;
  }

  void removeItem(String itemKey) {
    _items.remove(itemKey);
    notifyListeners();
  }

  void removeSingleItem(String itemKey) {
    if (!_items.containsKey(itemKey)) return;
    if (_items[itemKey]!.quantity > 1) {
      _items.update(itemKey, (existing) {
        existing.quantity--;
        return existing;
      });
    } else {
      _items.remove(itemKey);
    }
    notifyListeners();
  }

  void selectDineIn(int tableNumber) {
    _orderType = OrderType.dineIn;
    _orderIdentifier = 'Table $tableNumber';
    _tipAmount = 0.0;
    _splitCount = 1;
    notifyListeners();
  }

  Future<void> selectTakeaway() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCounter = prefs.getInt('takeawayCounter') ?? 1;
    _orderType = OrderType.takeaway;
    _orderIdentifier = 'Takeaway #$currentCounter';
    _serviceChargeEnabled = false;
    _tipAmount = 0.0;
    _splitCount = 1;
    await prefs.setInt('takeawayCounter', currentCounter + 1);
    notifyListeners();
  }

  Future<void> selectRetailSale() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCounter = prefs.getInt('retailCounter') ?? 1;
    _orderType = OrderType.retail;
    _orderIdentifier = 'Retail #$currentCounter';
    _serviceChargeEnabled = false;
    _tipAmount = 0.0;
    _splitCount = 1;
    await prefs.setInt('retailCounter', currentCounter + 1);
    notifyListeners();
  }

  Future<void> resetTakeawayCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('takeawayCounter', 1);
  }

  void loadOrder(
    Map<String, CartItem> items,
    String identifier, {
    bool serviceChargeEnabled = false,
    double? serviceChargeRate,
    double tipAmount = 0.0,
    int splitCount = 1,
  }) {
    _items = items;
    _orderIdentifier = identifier;
    if (identifier.startsWith('Table')) {
      _orderType = OrderType.dineIn;
    } else if (identifier.startsWith('Retail')) {
      _orderType = OrderType.retail;
    } else {
      _orderType = OrderType.takeaway;
    }
    _serviceChargeEnabled =
        serviceChargeEnabled && _orderType == OrderType.dineIn;
    if (serviceChargeRate != null) {
      setServiceChargeRate(serviceChargeRate);
    }
    _tipAmount = tipAmount;
    _splitCount = splitCount < 1 ? 1 : splitCount;
    notifyListeners();
  }
}
