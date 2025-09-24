import 'package:collection/collection.dart';

class CurrencySettings {
  const CurrencySettings({
    this.baseCurrency = 'THB',
    this.displayCurrency,
    this.supportedCurrencies = const <String>['THB'],
    this.autoRefreshDailyRates = false,
    this.lastRateSync,
  });

  final String baseCurrency;
  final String? displayCurrency;
  final List<String> supportedCurrencies;
  final bool autoRefreshDailyRates;
  final DateTime? lastRateSync;

  String get effectiveDisplayCurrency =>
      (displayCurrency ?? baseCurrency).toUpperCase();

  List<String> get normalizedSupportedCurrencies {
    final unique = <String>{
      baseCurrency.toUpperCase(),
      ...supportedCurrencies.map((e) => e.toUpperCase()),
    };
    return unique.toList(growable: false)..sort();
  }

  CurrencySettings copyWith({
    String? baseCurrency,
    String? displayCurrency,
    List<String>? supportedCurrencies,
    bool? autoRefreshDailyRates,
    DateTime? lastRateSync,
  }) {
    return CurrencySettings(
      baseCurrency: (baseCurrency ?? this.baseCurrency).toUpperCase(),
      displayCurrency: displayCurrency?.toUpperCase() ??
          this.displayCurrency?.toUpperCase(),
      supportedCurrencies: supportedCurrencies?.map((e) => e.toUpperCase()).toList() ??
          this.supportedCurrencies.map((e) => e.toUpperCase()).toList(),
      autoRefreshDailyRates:
          autoRefreshDailyRates ?? this.autoRefreshDailyRates,
      lastRateSync: lastRateSync ?? this.lastRateSync,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'baseCurrency': baseCurrency.toUpperCase(),
      if (displayCurrency != null)
        'displayCurrency': displayCurrency!.toUpperCase(),
      'supportedCurrencies': normalizedSupportedCurrencies,
      'autoRefreshDailyRates': autoRefreshDailyRates,
      if (lastRateSync != null) 'lastRateSync': lastRateSync!.toIso8601String(),
    };
  }

  factory CurrencySettings.fromMap(Map<String, dynamic> map) {
    final supported = (map['supportedCurrencies'] as List<dynamic>? ??
            const <dynamic>['THB'])
        .map((e) => (e as String).toUpperCase())
        .toList();
    return CurrencySettings(
      baseCurrency: (map['baseCurrency'] as String? ?? 'THB').toUpperCase(),
      displayCurrency: (map['displayCurrency'] as String?)?.toUpperCase(),
      supportedCurrencies: supported,
      autoRefreshDailyRates: map['autoRefreshDailyRates'] == true,
      lastRateSync: map['lastRateSync'] != null
          ? DateTime.tryParse(map['lastRateSync'] as String)
          : null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CurrencySettings &&
        other.baseCurrency.toUpperCase() == baseCurrency.toUpperCase() &&
        other.displayCurrency?.toUpperCase() ==
            displayCurrency?.toUpperCase() &&
        const ListEquality<String>().equals(
          other.normalizedSupportedCurrencies,
          normalizedSupportedCurrencies,
        ) &&
        other.autoRefreshDailyRates == autoRefreshDailyRates &&
        other.lastRateSync == lastRateSync;
  }

  @override
  int get hashCode => Object.hash(
        baseCurrency.toUpperCase(),
        displayCurrency?.toUpperCase(),
        const ListEquality<String>().hash(normalizedSupportedCurrencies),
        autoRefreshDailyRates,
        lastRateSync,
      );
}
