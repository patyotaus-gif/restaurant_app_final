// lib/models/tax_model.dart

import 'dart:math';

enum TaxRuleApplication { inclusive, exclusive }

enum TaxRoundingMode { halfUp, halfDown, bankers, up, down, none }

class TaxRule {
  final String id;
  final String name;
  final double rate;
  final TaxRuleApplication application;
  final bool applyToServiceCharge;
  final bool applyToTips;
  final List<String> categoryIds;
  final bool compound;
  final int priority;
  final bool enabled;

  const TaxRule({
    required this.id,
    required this.name,
    required this.rate,
    this.application = TaxRuleApplication.exclusive,
    this.applyToServiceCharge = false,
    this.applyToTips = false,
    this.categoryIds = const [],
    this.compound = false,
    this.priority = 0,
    this.enabled = true,
  });

  factory TaxRule.fromMap(Map<String, dynamic> data) {
    return TaxRule(
      id: data['id'] as String? ?? data['name'] as String? ?? 'rule',
      name: data['name'] as String? ?? 'Tax',
      rate: (data['rate'] as num?)?.toDouble() ?? 0.0,
      application: _parseApplication(data['application']),
      applyToServiceCharge: data['applyToServiceCharge'] == true,
      applyToTips: data['applyToTips'] == true,
      categoryIds: List<String>.from(
        data['categoryIds'] as List<dynamic>? ?? const [],
      ),
      compound: data['compound'] == true,
      priority: (data['priority'] as num?)?.toInt() ?? 0,
      enabled: data['enabled'] != false,
    );
  }

  static TaxRuleApplication _parseApplication(dynamic value) {
    final text = value?.toString().toLowerCase();
    switch (text) {
      case 'inclusive':
      case 'included':
        return TaxRuleApplication.inclusive;
      case 'exclusive':
      case 'excluded':
      default:
        return TaxRuleApplication.exclusive;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'rate': rate,
      'application': application.name,
      if (applyToServiceCharge) 'applyToServiceCharge': applyToServiceCharge,
      if (applyToTips) 'applyToTips': applyToTips,
      if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
      if (compound) 'compound': compound,
      if (priority != 0) 'priority': priority,
      'enabled': enabled,
    };
  }
}

class TaxRoundingConfig {
  final TaxRoundingMode mode;
  final int precision;
  final bool applyPerRule;

  const TaxRoundingConfig({
    this.mode = TaxRoundingMode.halfUp,
    this.precision = 2,
    this.applyPerRule = true,
  });

  factory TaxRoundingConfig.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const TaxRoundingConfig();
    }
    return TaxRoundingConfig(
      mode: _parseMode(data['mode']),
      precision: (data['precision'] as num?)?.toInt() ?? 2,
      applyPerRule: data['applyPerRule'] != false,
    );
  }

  static TaxRoundingMode _parseMode(dynamic value) {
    final text = value?.toString().toLowerCase();
    switch (text) {
      case 'halfdown':
      case 'half_down':
        return TaxRoundingMode.halfDown;
      case 'bankers':
      case 'bankersround':
      case 'bankers_round':
        return TaxRoundingMode.bankers;
      case 'up':
      case 'ceil':
        return TaxRoundingMode.up;
      case 'down':
      case 'floor':
        return TaxRoundingMode.down;
      case 'none':
      case 'truncate':
        return TaxRoundingMode.none;
      case 'halfup':
      case 'half_up':
      default:
        return TaxRoundingMode.halfUp;
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'mode': mode.name,
      'precision': precision,
      'applyPerRule': applyPerRule,
    };
  }

  double round(double value) {
    if (mode == TaxRoundingMode.none) {
      return value;
    }
    final factor = pow(10, precision).toDouble();
    final scaled = value * factor;
    switch (mode) {
      case TaxRoundingMode.halfUp:
        return (scaled.isNegative ? scaled - 0.5 : scaled + 0.5)
                .truncateToDouble() /
            factor;
      case TaxRoundingMode.halfDown:
        final adjustment = scaled.isNegative ? 0.5 : -0.5;
        return (scaled + adjustment).truncateToDouble() / factor;
      case TaxRoundingMode.bankers:
        final rounded = scaled.roundToDouble();
        if ((scaled - scaled.truncateToDouble()).abs() == 0.5) {
          final even = (scaled.truncate() % 2 == 0)
              ? scaled.truncateToDouble()
              : (scaled.truncateToDouble() + (scaled.isNegative ? -1 : 1));
          return even / factor;
        }
        return rounded / factor;
      case TaxRoundingMode.up:
        final ceilValue = scaled.isNegative
            ? scaled.floorToDouble()
            : scaled.ceilToDouble();
        return ceilValue / factor;
      case TaxRoundingMode.down:
        final floorValue = scaled.isNegative
            ? scaled.ceilToDouble()
            : scaled.floorToDouble();
        return floorValue / factor;
      case TaxRoundingMode.none:
        return value;
    }
  }
}

class TaxConfiguration {
  final bool enabled;
  final List<TaxRule> rules;
  final TaxRoundingConfig rounding;

  const TaxConfiguration({
    this.enabled = false,
    this.rules = const [],
    this.rounding = const TaxRoundingConfig(),
  });

  factory TaxConfiguration.fromMap(Map<String, dynamic>? data) {
    if (data == null) {
      return const TaxConfiguration();
    }
    final dynamic rulesRaw = data['rules'];
    final List<dynamic> rulesList = rulesRaw is List<dynamic>
        ? List<dynamic>.from(rulesRaw)
        : const [];
    final dynamic roundingRaw = data['rounding'];
    final Map<String, dynamic>? roundingMap =
        roundingRaw is Map<String, dynamic>
        ? Map<String, dynamic>.from(roundingRaw)
        : null;
    return TaxConfiguration(
      enabled: data['enabled'] != false,
      rules:
          rulesList
              .map(
                (rule) => rule is Map<String, dynamic>
                    ? TaxRule.fromMap(Map<String, dynamic>.from(rule))
                    : null,
              )
              .whereType<TaxRule>()
              .toList()
            ..sort((a, b) => a.priority.compareTo(b.priority)),
      rounding: TaxRoundingConfig.fromMap(roundingMap),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'enabled': enabled,
      'rules': rules.map((rule) => rule.toMap()).toList(),
      'rounding': rounding.toMap(),
    };
  }

  bool get hasRules => enabled && rules.any((rule) => rule.enabled);
}

class TaxLine {
  final String id;
  final String name;
  final double amount;

  const TaxLine({required this.id, required this.name, required this.amount});
}

class TaxComputationResult {
  final double exclusiveTax;
  final double inclusiveTaxPortion;
  final double roundingDelta;
  final List<TaxLine> lines;

  const TaxComputationResult({
    this.exclusiveTax = 0,
    this.inclusiveTaxPortion = 0,
    this.roundingDelta = 0,
    this.lines = const [],
  });

  factory TaxComputationResult.empty() => const TaxComputationResult();

  double get totalTax => exclusiveTax + inclusiveTaxPortion + roundingDelta;

  Map<String, double> get breakdown => {
    for (final line in lines) line.name: line.amount,
  };

  Map<String, dynamic> toMap() {
    return {
      'exclusiveTax': exclusiveTax,
      'inclusiveTaxPortion': inclusiveTaxPortion,
      'roundingDelta': roundingDelta,
      'total': totalTax,
      'lines': lines
          .map(
            (line) => {'id': line.id, 'name': line.name, 'amount': line.amount},
          )
          .toList(),
    };
  }
}
