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

  Map<String, CartItem> get items => {..._items};
  OrderType? get orderType => _orderType;
  String? get orderIdentifier => _orderIdentifier;
  int get itemCount => _items.length;
  Customer? get customer => _customer;
  double get discount => _discount;
  String get discountType => _discountType;
  Promotion? get appliedPromotion => _appliedPromotion;

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

  double get totalAmount {
    final total = subtotal - _discount;
    return total < 0 ? 0 : total;
  }

  int get totalQuantity {
    var total = 0;
    _items.forEach((key, cartItem) {
      total += cartItem.quantity;
    });
    return total;
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

  void clear() {
    _items = {};
    _orderType = null;
    _orderIdentifier = null;
    _customer = null;
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
    notifyListeners();
  }

  Future<void> selectTakeaway() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCounter = prefs.getInt('takeawayCounter') ?? 1;
    _orderType = OrderType.takeaway;
    _orderIdentifier = 'Takeaway #$currentCounter';
    await prefs.setInt('takeawayCounter', currentCounter + 1);
    notifyListeners();
  }

  Future<void> selectRetailSale() async {
    final prefs = await SharedPreferences.getInstance();
    int currentCounter = prefs.getInt('retailCounter') ?? 1;
    _orderType = OrderType.retail;
    _orderIdentifier = 'Retail #$currentCounter';
    await prefs.setInt('retailCounter', currentCounter + 1);
    notifyListeners();
  }

  Future<void> resetTakeawayCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('takeawayCounter', 1);
  }

  void loadOrder(Map<String, CartItem> items, String identifier) {
    _items = items;
    _orderIdentifier = identifier;
    _orderType = identifier.startsWith('Table')
        ? OrderType.dineIn
        : OrderType.takeaway;
    notifyListeners();
  }
}
