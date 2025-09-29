import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'client_cache_service.dart';
import 'firestore_converters.dart';
class MenuCacheProvider with ChangeNotifier {
  MenuCacheProvider(this._firestore, this._cacheService) {
    _initialize();
  }

  final FirebaseFirestore _firestore;
  final ClientCacheService _cacheService;

  StreamSubscription<QuerySnapshot<Product>>? _subscription;
  List<Product> _menuItems = [];
  Map<String, Product> _productsById = {};
  Map<String, Product> _productsByBarcode = {};
  bool _hasFreshData = false;
  bool _hasResolvedCache = false;

  bool get hasFreshData => _hasFreshData;
  bool get hasCacheResolved => _hasResolvedCache;
  bool get isReady => _hasFreshData || _hasResolvedCache;

  List<Product> get menuItems => List.unmodifiable(_menuItems);

  Map<String, double> get priceMap => {
    for (final entry in _productsById.entries) entry.key: entry.value.price,
  };

  Product? productById(String id) => _productsById[id];

  Product? productByBarcode(String barcode) => _productsByBarcode[barcode];

  List<Product> productsByCategory(String category) {
    if (category.isEmpty) {
      return menuItems;
    }
    return _menuItems
        .where((product) => product.category == category)
        .toList(growable: false);
  }

  void _initialize() {
    Future.microtask(() async {
      await _loadFromCache();
      _subscribeToMenuItems();
    });
  }

  Future<void> _loadFromCache() async {
    final cached = await _cacheService.readMenuItems();
    if (cached != null && cached.isNotEmpty) {
      _hasResolvedCache = true;
      _applyMenuItems(cached, fresh: false);
    }
  }

  void _subscribeToMenuItems() {
    _subscription?.cancel();
    _subscription = _firestore
        .menuItemsRef
        .snapshots()
        .listen(
          (snapshot) {
            final items = snapshot.docs
                .map((doc) => doc.data())
                .toList(growable: false);
            _applyMenuItems(items, fresh: true);
            unawaited(_cacheService.cacheMenuItems(items));
          },
          onError: (Object error, StackTrace stackTrace) {
            debugPrint('MenuCacheProvider stream error: $error');
          },
        );
  }

  void _applyMenuItems(List<Product> items, {required bool fresh}) {
    _menuItems = items;
    _productsById = {
      for (final item in items)
        if (item.id.isNotEmpty) item.id: item,
    };
    _productsByBarcode = {
      for (final item in items)
        if (item.barcode.isNotEmpty) item.barcode: item,
    };
    if (fresh) {
      _hasFreshData = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
