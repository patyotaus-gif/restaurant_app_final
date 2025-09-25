import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider extends ChangeNotifier {
  LocaleProvider() {
    _loadPreferredLocale();
  }

  static const _preferenceKey = 'app_locale';
  SharedPreferences? _preferences;
  Locale? _locale;
  bool _initialized = false;

  Locale? get locale => _locale;
  bool get isInitialized => _initialized;

  Future<void> setLocale(Locale? locale) async {
    final prefs = await _ensurePreferences();
    Locale? resolvedLocale;
    String? storeValue;

    if (locale != null) {
      final canonical = Intl.canonicalizedLocale(locale.toLanguageTag());
      storeValue = canonical;
      resolvedLocale = _localeFromTag(canonical);
      Intl.defaultLocale = canonical;
    } else {
      await prefs.remove(_preferenceKey);
      Intl.defaultLocale = null;
    }

    if (storeValue != null) {
      await prefs.setString(_preferenceKey, storeValue);
    }

    if (_locale?.toLanguageTag() != resolvedLocale?.toLanguageTag()) {
      _locale = resolvedLocale;
      notifyListeners();
    }
  }

  NumberFormat decimalFormatter({int? decimalDigits}) {
    final formatter = NumberFormat.decimalPattern(_effectiveLocaleName);
    if (decimalDigits != null) {
      formatter
        ..minimumFractionDigits = decimalDigits
        ..maximumFractionDigits = decimalDigits;
    }
    return formatter;
  }

  String formatNumber(num value, {int? decimalDigits}) {
    return decimalFormatter(decimalDigits: decimalDigits).format(value);
  }

  String formatValueWithUnit(num value, String unit, {int? decimalDigits}) {
    final number = formatNumber(value, decimalDigits: decimalDigits);
    return '$number $unit';
  }

  Future<void> _loadPreferredLocale() async {
    final prefs = await _ensurePreferences();
    final stored = prefs.getString(_preferenceKey);
    if (stored != null && stored.isNotEmpty) {
      _locale = _localeFromTag(stored);
      Intl.defaultLocale = stored;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<SharedPreferences> _ensurePreferences() async {
    if (_preferences != null) {
      return _preferences!;
    }
    _preferences = await SharedPreferences.getInstance();
    return _preferences!;
  }

  Locale? _localeFromTag(String tag) {
    final canonical = Intl.canonicalizedLocale(tag);
    final segments = canonical.split(RegExp('[-_]'));
    if (segments.length == 1) {
      return Locale(segments.first);
    }
    return Locale(segments.first, segments[1]);
  }

  String get _effectiveLocaleName {
    return _locale?.toLanguageTag() ?? Intl.getCurrentLocale();
  }
}
