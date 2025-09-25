// lib/app_mode_provider.dart

import 'package:flutter/material.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:shared_preferences/shared_preferences.dart';
class AppModeProvider with ChangeNotifier {
  AppMode _appMode = AppMode.restaurant; // Default mode
  bool _isLoading = true;

  AppMode get appMode => _appMode;
  bool get isLoading => _isLoading;

  AppModeProvider() {
    _loadAppMode();
  }

  Future<void> _loadAppMode() async {
    final prefs = await SharedPreferences.getInstance();
    final modeString = prefs.getString('appMode') ?? AppMode.restaurant.name;
    _appMode = AppMode.values.firstWhere((e) => e.name == modeString);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> setAppMode(AppMode newMode) async {
    if (_appMode == newMode) return;

    _appMode = newMode;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('appMode', newMode.name);
  }
}
