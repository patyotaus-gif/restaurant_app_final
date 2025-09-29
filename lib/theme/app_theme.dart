import 'package:flutter/material.dart';

import '../accessibility_provider.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(AccessibilityProvider accessibility) {
    final colorScheme = accessibility.highContrast
        ? ColorScheme.highContrastLight(primary: Colors.indigo)
        : ColorScheme.fromSeed(seedColor: Colors.indigo);
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: colorScheme,
      useMaterial3: true,
    );
    return _applyShared(base, accessibility);
  }

  static ThemeData dark(AccessibilityProvider accessibility) {
    final colorScheme = accessibility.highContrast
        ? ColorScheme.highContrastDark(primary: Colors.indigo)
        : ColorScheme.fromSeed(
            seedColor: Colors.indigo,
            brightness: Brightness.dark,
          );
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      useMaterial3: true,
    );
    return _applyShared(base, accessibility);
  }

  static ThemeData _applyShared(
    ThemeData base,
    AccessibilityProvider accessibility,
  ) {
    final scale = accessibility.largeText ? 1.08 : 1.0;
    final textTheme = base.textTheme.apply(fontSizeFactor: scale);
    return base.copyWith(
      textTheme: textTheme,
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: base.colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: base.colorScheme.onInverseSurface,
        ),
        actionTextColor: base.colorScheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: base.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }
}
