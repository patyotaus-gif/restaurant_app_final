import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AccessibilityProvider with ChangeNotifier {
  AccessibilityProvider() {
    _load();
  }

  static const _prefsLargeTextKey = 'accessibility.largeText';
  static const _prefsHighContrastKey = 'accessibility.highContrast';

  bool _largeText = false;
  bool _highContrast = false;

  bool get largeText => _largeText;
  bool get highContrast => _highContrast;

  double get textScaleFactor => _largeText ? 1.2 : 1.0;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _largeText = prefs.getBool(_prefsLargeTextKey) ?? false;
    _highContrast = prefs.getBool(_prefsHighContrastKey) ?? false;
    notifyListeners();
  }

  Future<void> setLargeText(bool value) async {
    if (_largeText == value) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _largeText = value;
    await prefs.setBool(_prefsLargeTextKey, value);
    notifyListeners();
  }

  Future<void> setHighContrast(bool value) async {
    if (_highContrast == value) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    _highContrast = value;
    await prefs.setBool(_prefsHighContrastKey, value);
    notifyListeners();
  }

  void toggleLargeText() {
    setLargeText(!_largeText);
  }

  void toggleHighContrast() {
    setHighContrast(!_highContrast);
  }
}
