// lib/services/tax_service.dart

import 'dart:math';

import 'package:restaurant_models/restaurant_models.dart';
class AdvancedTaxEngine {
  const AdvancedTaxEngine();

  TaxComputationResult calculate({
    required double subtotal,
    required double discount,
    required double serviceCharge,
    required Map<String, double> categoryTotals,
    required TaxConfiguration configuration,
    double tipAmount = 0,
  }) {
    if (!configuration.hasRules) {
      return TaxComputationResult.empty();
    }

    final rules = configuration.rules.where((rule) => rule.enabled).toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));

    final rounding = configuration.rounding;
    final lines = <TaxLine>[];

    double exclusiveTax = 0;
    double inclusivePortion = 0;
    double roundingDelta = 0;

    final baseSubtotal = max(subtotal - discount, 0).toDouble();

    for (final rule in rules) {
      final base = _resolveBaseAmount(
        rule,
        baseSubtotal: baseSubtotal,
        serviceCharge: serviceCharge,
        tipAmount: tipAmount,
        categoryTotals: categoryTotals,
        exclusiveTax: exclusiveTax,
        inclusiveTax: inclusivePortion,
      );

      if (base <= 0 || rule.rate == 0) {
        continue;
      }

      double amount;
      if (rule.application == TaxRuleApplication.inclusive) {
        amount = base - (base / (1 + rule.rate));
        inclusivePortion += amount;
      } else {
        amount = base * rule.rate;
        exclusiveTax += amount;
      }

      if (rounding.applyPerRule) {
        final rounded = rounding.round(amount);
        roundingDelta += rounded - amount;
        amount = rounded;
      }

      lines.add(TaxLine(id: rule.id, name: rule.name, amount: amount));
    }

    if (!rounding.applyPerRule) {
      final summed = lines.fold<double>(
        0,
        (value, line) => value + line.amount,
      );
      final rounded = rounding.round(summed);
      roundingDelta = rounded - summed;
    }

    return TaxComputationResult(
      exclusiveTax: exclusiveTax,
      inclusiveTaxPortion: inclusivePortion,
      roundingDelta: roundingDelta,
      lines: lines,
    );
  }

  double _resolveBaseAmount(
    TaxRule rule, {
    required double baseSubtotal,
    required double serviceCharge,
    required double tipAmount,
    required Map<String, double> categoryTotals,
    required double exclusiveTax,
    required double inclusiveTax,
  }) {
    double base = 0;

    if (rule.categoryIds.isEmpty) {
      base = baseSubtotal;
    } else {
      for (final category in rule.categoryIds) {
        base += categoryTotals[category] ?? 0;
      }
    }

    if (rule.applyToServiceCharge) {
      base += serviceCharge;
    }

    if (rule.applyToTips) {
      base += tipAmount;
    }

    if (rule.compound) {
      base += exclusiveTax + inclusiveTax;
    }

    return base;
  }
}
