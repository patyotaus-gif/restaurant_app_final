import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'models/currency_settings.dart';
import 'models/store_model.dart';
import 'models/fx_rate.dart';
import 'services/fx_rate_service.dart';

class CurrencyProvider with ChangeNotifier {
  CurrencyProvider(this._fxRateService);

  final FxRateService _fxRateService;
  StreamSubscription<Map<String, double>>? _subscription;
  CurrencySettings _settings = const CurrencySettings();
  Map<String, double> _rates = const {'THB': 1.0};
  String? _activeStoreId;
  String? _overrideDisplayCurrency;
  DateTime? _lastSynced;

  CurrencySettings get settings => _settings;
  String get baseCurrency => _settings.baseCurrency.toUpperCase();
  String get displayCurrency =>
      (_overrideDisplayCurrency ?? _settings.effectiveDisplayCurrency)
          .toUpperCase();
  List<String> get supportedCurrencies =>
      _settings.normalizedSupportedCurrencies;
  DateTime? get lastSynced => _lastSynced;

  Map<String, double> get quotedRates =>
      Map.unmodifiable(_rates.map((key, value) => MapEntry(key.toUpperCase(), value)));

  NumberFormat get currencyFormatter =>
      NumberFormat.simpleCurrency(name: displayCurrency);

  Future<void> applyStore(Store? store) async {
    final newStoreId = store?.id;
    final newSettings = store?.currencySettings ?? const CurrencySettings();
    final shouldUpdateSettings =
        _activeStoreId != newStoreId || _settings != newSettings;

    if (!shouldUpdateSettings) {
      return;
    }

    _subscription?.cancel();
    _activeStoreId = newStoreId;
    _settings = newSettings;
    _overrideDisplayCurrency = null;

    _rates = {
      _settings.baseCurrency.toUpperCase(): 1.0,
      for (final currency in _settings.supportedCurrencies)
        currency.toUpperCase(): _rates[currency.toUpperCase()] ?? 1.0,
    };

    notifyListeners();
    await refreshRates();
    if (_settings.autoRefreshDailyRates) {
      _subscription = _fxRateService
          .watchRates(baseCurrency: baseCurrency)
          .listen((event) {
        _applyRates(event);
      });
    }
  }

  void setDisplayCurrency(String currency) {
    final normalized = currency.toUpperCase();
    if (!supportedCurrencies.contains(normalized)) {
      return;
    }
    if (_overrideDisplayCurrency == normalized) {
      return;
    }
    _overrideDisplayCurrency = normalized;
    notifyListeners();
  }

  double convert({
    required double amount,
    String? fromCurrency,
    String? toCurrency,
  }) {
    final from = (fromCurrency ?? baseCurrency).toUpperCase();
    final to = (toCurrency ?? displayCurrency).toUpperCase();
    if (from == to) {
      return amount;
    }
    if (from != baseCurrency) {
      final inverseRate = _rates[from];
      if (inverseRate != null && inverseRate > 0) {
        final baseAmount = amount / inverseRate;
        return convert(amount: baseAmount, fromCurrency: baseCurrency, toCurrency: to);
      }
    }
    final rate = _rates[to];
    if (rate == null || rate <= 0) {
      return amount;
    }
    return amount * rate;
  }

  String formatBaseAmount(double amount, {String? targetCurrency}) {
    final converted = convert(
      amount: amount,
      fromCurrency: baseCurrency,
      toCurrency: targetCurrency ?? displayCurrency,
    );
    final formatter = NumberFormat.simpleCurrency(
      name: (targetCurrency ?? displayCurrency).toUpperCase(),
    );
    return formatter.format(converted);
  }

  Future<void> refreshRates({DateTime? asOf}) async {
    final fetched = await _fxRateService.loadRates(
      baseCurrency: baseCurrency,
      asOf: asOf,
    );
    _applyRates(fetched);
  }

  Future<void> upsertRate(FxRate rate) async {
    await _fxRateService.upsertRate(rate: rate);
    await refreshRates(asOf: rate.asOf);
  }

  void _applyRates(Map<String, double> rates) {
    if (rates.isEmpty) {
      _lastSynced = DateTime.now();
      notifyListeners();
      return;
    }
    final nextRates = <String, double>{baseCurrency: 1.0};
    rates.forEach((currency, value) {
      nextRates[currency.toUpperCase()] = value;
    });
    for (final currency in supportedCurrencies) {
      nextRates.putIfAbsent(currency.toUpperCase(), () =>
          currency.toUpperCase() == baseCurrency ? 1.0 : (_rates[currency.toUpperCase()] ?? 1.0));
    }
    _rates = nextRates;
    _lastSynced = DateTime.now();
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
