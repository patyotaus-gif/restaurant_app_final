import 'package:flutter/widgets.dart';
import 'app_localizations.dart';
import 'package:intl/intl.dart';

extension AppLocalizationsX on AppLocalizations {
  String localizedUnitLabel(String unit) {
    final normalized = unit.trim().toLowerCase();
    switch (normalized) {
      case 'kg':
      case 'kilogram':
      case 'kilograms':
        return unitKilogram;
      case 'g':
      case 'gram':
      case 'grams':
        return unitGram;
      case 'l':
      case 'liter':
      case 'litre':
      case 'liters':
      case 'litres':
        return unitLiter;
      case 'ml':
      case 'milliliter':
      case 'millilitre':
      case 'milliliters':
      case 'millilitres':
        return unitMilliliter;
      case 'pc':
      case 'pcs':
      case 'piece':
      case 'pieces':
        return unitPiece;
      default:
        return unit;
    }
  }

  String formatValueWithUnit(num value, String unit, {int? decimalDigits}) {
    final format = NumberFormat.decimalPattern(Intl.getCurrentLocale());
    if (decimalDigits != null) {
      format
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    }
    final number = format.format(value);
    return valueWithUnit(number, localizedUnitLabel(unit));
  }

  String describeLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'th':
        return languageThai;
      case 'en':
      default:
        return languageEnglish;
    }
  }
}
