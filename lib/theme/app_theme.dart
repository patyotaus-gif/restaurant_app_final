import 'package:flutter/material.dart';

import '../accessibility_provider.dart';
import 'design_tokens.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData light(AccessibilityProvider accessibility) {
    final colorTokens = accessibility.highContrast
        ? AppColorTokens.highContrastLight
        : AppColorTokens.light;
    final colorScheme = accessibility.highContrast
        ? ColorScheme.highContrastLight(primary: colorTokens.primary)
        : ColorScheme.fromSeed(seedColor: colorTokens.primary);
    final base = ThemeData(
      brightness: Brightness.light,
      colorScheme: _applyColorTokens(colorScheme, colorTokens),
      scaffoldBackgroundColor: colorTokens.background,
      useMaterial3: true,
    );
    return _applyShared(base, accessibility, colorTokens);
  }

  static ThemeData dark(AccessibilityProvider accessibility) {
    final colorTokens = accessibility.highContrast
        ? AppColorTokens.highContrastDark
        : AppColorTokens.dark;
    final colorScheme = accessibility.highContrast
        ? ColorScheme.highContrastDark(primary: colorTokens.primary)
        : ColorScheme.fromSeed(
            seedColor: colorTokens.primary,
            brightness: Brightness.dark,
          );
    final base = ThemeData(
      brightness: Brightness.dark,
      colorScheme: _applyColorTokens(colorScheme, colorTokens),
      scaffoldBackgroundColor: colorTokens.background,
      useMaterial3: true,
    );
    return _applyShared(base, accessibility, colorTokens);
  }

  static ThemeData _applyShared(
    ThemeData base,
    AccessibilityProvider accessibility,
    AppColorTokens colorTokens,
  ) {
    final scale = accessibility.largeText ? 1.08 : 1.0;
    final textTheme = base.textTheme.apply(fontSizeFactor: scale);
    const spacingTokens = AppSpacingTokens.regular;
    const radiusTokens = AppRadiusTokens.regular;
    const durationTokens = AppDurationTokens.regular;
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
          borderRadius: radiusTokens.largeRadius,
        ),
        showCloseIcon: true,
      ),
      appBarTheme: base.appBarTheme.copyWith(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: base.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
      floatingActionButtonTheme: base.floatingActionButtonTheme.copyWith(
        shape: RoundedRectangleBorder(
          borderRadius: radiusTokens.extraLargeRadius,
        ),
      ),
      cardTheme: base.cardTheme.copyWith(
        margin: EdgeInsets.all(spacingTokens.m),
        shape: RoundedRectangleBorder(
          borderRadius: radiusTokens.mediumRadius,
        ),
        elevation: 3,
      ),
      tooltipTheme: base.tooltipTheme.copyWith(
        waitDuration: durationTokens.short,
        showDuration: durationTokens.medium,
        padding: EdgeInsets.symmetric(
          horizontal: spacingTokens.s,
          vertical: spacingTokens.xs,
        ),
      ),
      extensions: [
        ...base.extensions.values,
        colorTokens,
        spacingTokens,
        radiusTokens,
        durationTokens,
      ],
    );
  }

  static ColorScheme _applyColorTokens(
    ColorScheme scheme,
    AppColorTokens colors,
  ) {
    return scheme.copyWith(
      primary: colors.primary,
      onPrimary: colors.onPrimary,
      secondary: colors.secondary,
      onSecondary: colors.onSecondary,
      surface: colors.surface,
      onSurface: colors.onSurface,
      background: colors.background,
      onBackground: colors.onBackground,
      error: colors.error,
      onError: colors.onError,
    );
  }
}
