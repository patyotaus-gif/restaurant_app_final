import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  ThemeProvider() {
    _loadThemeMode();
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final theme = prefs.getString('themeMode') ?? 'system';
    if (theme == 'light') {
      _themeMode = ThemeMode.light;
    } else if (theme == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    notifyListeners();
  }

  void setTheme(ThemeMode themeMode) async {
    final prefs = await SharedPreferences.getInstance();
    _themeMode = themeMode;
    if (themeMode == ThemeMode.light) {
      await prefs.setString('themeMode', 'light');
    } else if (themeMode == ThemeMode.dark) {
      await prefs.setString('themeMode', 'dark');
    } else {
      await prefs.setString('themeMode', 'system');
    }
    notifyListeners();
  }
}
