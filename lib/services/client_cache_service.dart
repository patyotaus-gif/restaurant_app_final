import 'dart:convert';

import 'package:restaurant_models/restaurant_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feature_flags/feature_flag_configuration.dart';
class ClientCacheService {
  ClientCacheService();

  SharedPreferences? _preferences;

  static const String _menuKey = 'client_cache.menu.v1';
  static const String _menuTimestampKey = 'client_cache.menu.v1.updated';

  static const String _priceKey = 'client_cache.prices.v1';
  static const String _priceTimestampKey = 'client_cache.prices.v1.updated';

  static const String _flagKeyPrefix = 'client_cache.flags.v1.';
  static const String _flagTimestampPrefix = 'client_cache.flags.v1.updated.';

  Future<SharedPreferences> get _prefs async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  Future<void> cacheMenuItems(
    List<Product> products, {
    DateTime? fetchedAt,
  }) async {
    final prefs = await _prefs;
    final timestamp = (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final serialized = jsonEncode(
      products.map((product) => product.toJson()).toList(),
    );
    await prefs.setString(_menuKey, serialized);
    await prefs.setInt(_menuTimestampKey, timestamp);

    final priceMap = <String, double>{
      for (final product in products) product.id: product.price,
    };
    await prefs.setString(_priceKey, jsonEncode(priceMap));
    await prefs.setInt(_priceTimestampKey, timestamp);
  }

  Future<List<Product>?> readMenuItems({Duration? maxAge}) async {
    final prefs = await _prefs;
    final payload = prefs.getString(_menuKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    if (_isStale(timestamp: prefs.getInt(_menuTimestampKey), maxAge: maxAge)) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as List<dynamic>;
      return decoded
          .whereType<Map<String, dynamic>>()
          .map(Product.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, double>?> readPriceMap({Duration? maxAge}) async {
    final prefs = await _prefs;
    final payload = prefs.getString(_priceKey);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    if (_isStale(timestamp: prefs.getInt(_priceTimestampKey), maxAge: maxAge)) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return decoded.map(
        (key, value) => MapEntry(key, (value as num).toDouble()),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> cacheFeatureFlags({
    required String tenantId,
    required FeatureFlagConfiguration configuration,
    DateTime? fetchedAt,
  }) async {
    final prefs = await _prefs;
    final timestamp = (fetchedAt ?? DateTime.now()).millisecondsSinceEpoch;
    final key = '$_flagKeyPrefix$tenantId';
    final tsKey = '$_flagTimestampPrefix$tenantId';
    await prefs.setString(key, jsonEncode(configuration.toMap()));
    await prefs.setInt(tsKey, timestamp);
  }

  Future<FeatureFlagConfiguration?> readFeatureFlags({
    required String tenantId,
    Duration? maxAge,
  }) async {
    final prefs = await _prefs;
    final key = '$_flagKeyPrefix$tenantId';
    final tsKey = '$_flagTimestampPrefix$tenantId';
    final payload = prefs.getString(key);
    if (payload == null || payload.isEmpty) {
      return null;
    }

    if (_isStale(timestamp: prefs.getInt(tsKey), maxAge: maxAge)) {
      return null;
    }

    try {
      final decoded = jsonDecode(payload) as Map<String, dynamic>;
      return FeatureFlagConfiguration.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  bool _isStale({int? timestamp, Duration? maxAge}) {
    if (maxAge == null) {
      return false;
    }
    if (timestamp == null) {
      return true;
    }
    final fetchedAt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return DateTime.now().difference(fetchedAt) > maxAge;
  }
}
