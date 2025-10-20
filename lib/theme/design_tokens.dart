import 'package:flutter/material.dart';

/// Defines the application's semantic color palette.
class AppColorTokens extends ThemeExtension<AppColorTokens> {
  const AppColorTokens({
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.onSecondary,
    required this.surface,
    required this.onSurface,
    required this.background,
    required this.onBackground,
    required this.error,
    required this.onError,
  });

  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color onSecondary;
  final Color surface;
  final Color onSurface;
  final Color background;
  final Color onBackground;
  final Color error;
  final Color onError;

  static const AppColorTokens light = AppColorTokens(
    primary: Color(0xFF4E5AE8),
    onPrimary: Colors.white,
    secondary: Color(0xFF56C8D8),
    onSecondary: Colors.black,
    surface: Color(0xFFF8FAFD),
    onSurface: Color(0xFF1A1C1E),
    background: Color(0xFFF2F4F8),
    onBackground: Color(0xFF1A1C1E),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
  );

  static const AppColorTokens dark = AppColorTokens(
    primary: Color(0xFFBCC3FF),
    onPrimary: Color(0xFF12206A),
    secondary: Color(0xFF7EE8F5),
    onSecondary: Color(0xFF00363E),
    surface: Color(0xFF111417),
    onSurface: Color(0xFFE1E3E7),
    background: Color(0xFF0D1013),
    onBackground: Color(0xFFE1E3E7),
    error: Color(0xFFFFB4A9),
    onError: Color(0xFF680003),
  );

  static const AppColorTokens highContrastLight = AppColorTokens(
    primary: Colors.indigo,
    onPrimary: Colors.white,
    secondary: Color(0xFF0D47A1),
    onSecondary: Colors.white,
    surface: Colors.white,
    onSurface: Colors.black,
    background: Color(0xFFF2F4F8),
    onBackground: Colors.black,
    error: Color(0xFFB00020),
    onError: Colors.white,
  );

  static const AppColorTokens highContrastDark = AppColorTokens(
    primary: Colors.indigoAccent,
    onPrimary: Colors.black,
    secondary: Colors.cyanAccent,
    onSecondary: Colors.black,
    surface: Color(0xFF0A0A0A),
    onSurface: Colors.white,
    background: Color(0xFF000000),
    onBackground: Colors.white,
    error: Color(0xFFFFB4B4),
    onError: Colors.black,
  );

  @override
  AppColorTokens copyWith({
    Color? primary,
    Color? onPrimary,
    Color? secondary,
    Color? onSecondary,
    Color? surface,
    Color? onSurface,
    Color? background,
    Color? onBackground,
    Color? error,
    Color? onError,
  }) {
    return AppColorTokens(
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      secondary: secondary ?? this.secondary,
      onSecondary: onSecondary ?? this.onSecondary,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  ThemeExtension<AppColorTokens> lerp(
    covariant ThemeExtension<AppColorTokens>? other,
    double t,
  ) {
    if (other is! AppColorTokens) {
      return this;
    }

    return AppColorTokens(
      primary: Color.lerp(primary, other.primary, t) ?? primary,
      onPrimary: Color.lerp(onPrimary, other.onPrimary, t) ?? onPrimary,
      secondary: Color.lerp(secondary, other.secondary, t) ?? secondary,
      onSecondary: Color.lerp(onSecondary, other.onSecondary, t) ?? onSecondary,
      surface: Color.lerp(surface, other.surface, t) ?? surface,
      onSurface: Color.lerp(onSurface, other.onSurface, t) ?? onSurface,
      background: Color.lerp(background, other.background, t) ?? background,
      onBackground:
          Color.lerp(onBackground, other.onBackground, t) ?? onBackground,
      error: Color.lerp(error, other.error, t) ?? error,
      onError: Color.lerp(onError, other.onError, t) ?? onError,
    );
  }
}

/// Defines the spacing scale used across the app.
class AppSpacingTokens extends ThemeExtension<AppSpacingTokens> {
  const AppSpacingTokens({
    required this.xxxs,
    required this.xxs,
    required this.xs,
    required this.s,
    required this.m,
    required this.l,
    required this.xl,
    required this.xxl,
  });

  final double xxxs;
  final double xxs;
  final double xs;
  final double s;
  final double m;
  final double l;
  final double xl;
  final double xxl;

  static const AppSpacingTokens regular = AppSpacingTokens(
    xxxs: 2,
    xxs: 4,
    xs: 8,
    s: 12,
    m: 16,
    l: 24,
    xl: 32,
    xxl: 48,
  );

  @override
  AppSpacingTokens copyWith({
    double? xxxs,
    double? xxs,
    double? xs,
    double? s,
    double? m,
    double? l,
    double? xl,
    double? xxl,
  }) {
    return AppSpacingTokens(
      xxxs: xxxs ?? this.xxxs,
      xxs: xxs ?? this.xxs,
      xs: xs ?? this.xs,
      s: s ?? this.s,
      m: m ?? this.m,
      l: l ?? this.l,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
    );
  }

  @override
  ThemeExtension<AppSpacingTokens> lerp(
    covariant ThemeExtension<AppSpacingTokens>? other,
    double t,
  ) {
    if (other is! AppSpacingTokens) {
      return this;
    }

    double lerp(double a, double b) => a + (b - a) * t;

    return AppSpacingTokens(
      xxxs: lerp(xxxs, other.xxxs),
      xxs: lerp(xxs, other.xxs),
      xs: lerp(xs, other.xs),
      s: lerp(s, other.s),
      m: lerp(m, other.m),
      l: lerp(l, other.l),
      xl: lerp(xl, other.xl),
      xxl: lerp(xxl, other.xxl),
    );
  }
}

/// Defines the radius scale used across the app.
class AppRadiusTokens extends ThemeExtension<AppRadiusTokens> {
  const AppRadiusTokens({
    required this.small,
    required this.medium,
    required this.large,
    required this.extraLarge,
  });

  final double small;
  final double medium;
  final double large;
  final double extraLarge;

  static const AppRadiusTokens regular = AppRadiusTokens(
    small: 4,
    medium: 8,
    large: 12,
    extraLarge: 20,
  );

  BorderRadius get smallRadius => BorderRadius.circular(small);
  BorderRadius get mediumRadius => BorderRadius.circular(medium);
  BorderRadius get largeRadius => BorderRadius.circular(large);
  BorderRadius get extraLargeRadius => BorderRadius.circular(extraLarge);

  @override
  AppRadiusTokens copyWith({
    double? small,
    double? medium,
    double? large,
    double? extraLarge,
  }) {
    return AppRadiusTokens(
      small: small ?? this.small,
      medium: medium ?? this.medium,
      large: large ?? this.large,
      extraLarge: extraLarge ?? this.extraLarge,
    );
  }

  @override
  ThemeExtension<AppRadiusTokens> lerp(
    covariant ThemeExtension<AppRadiusTokens>? other,
    double t,
  ) {
    if (other is! AppRadiusTokens) {
      return this;
    }

    double lerp(double a, double b) => a + (b - a) * t;

    return AppRadiusTokens(
      small: lerp(small, other.small),
      medium: lerp(medium, other.medium),
      large: lerp(large, other.large),
      extraLarge: lerp(extraLarge, other.extraLarge),
    );
  }
}

/// Defines the motion durations used across the app.
class AppDurationTokens extends ThemeExtension<AppDurationTokens> {
  const AppDurationTokens({
    required this.instant,
    required this.short,
    required this.medium,
    required this.long,
  });

  final Duration instant;
  final Duration short;
  final Duration medium;
  final Duration long;

  static const AppDurationTokens regular = AppDurationTokens(
    instant: Duration(milliseconds: 80),
    short: Duration(milliseconds: 160),
    medium: Duration(milliseconds: 280),
    long: Duration(milliseconds: 400),
  );

  @override
  AppDurationTokens copyWith({
    Duration? instant,
    Duration? short,
    Duration? medium,
    Duration? long,
  }) {
    return AppDurationTokens(
      instant: instant ?? this.instant,
      short: short ?? this.short,
      medium: medium ?? this.medium,
      long: long ?? this.long,
    );
  }

  @override
  ThemeExtension<AppDurationTokens> lerp(
    covariant ThemeExtension<AppDurationTokens>? other,
    double t,
  ) {
    if (other is! AppDurationTokens) {
      return this;
    }

    Duration lerp(Duration a, Duration b) {
      final microseconds =
          (a.inMicroseconds + (b.inMicroseconds - a.inMicroseconds) * t)
              .round();
      return Duration(microseconds: microseconds);
    }

    return AppDurationTokens(
      instant: lerp(instant, other.instant),
      short: lerp(short, other.short),
      medium: lerp(medium, other.medium),
      long: lerp(long, other.long),
    );
  }
}

extension ThemeDesignTokens on BuildContext {
  AppColorTokens get colors =>
      Theme.of(this).extension<AppColorTokens>() ?? AppColorTokens.light;
  AppSpacingTokens get spacing =>
      Theme.of(this).extension<AppSpacingTokens>() ?? AppSpacingTokens.regular;
  AppRadiusTokens get radii =>
      Theme.of(this).extension<AppRadiusTokens>() ?? AppRadiusTokens.regular;
  AppDurationTokens get durations =>
      Theme.of(this).extension<AppDurationTokens>() ??
      AppDurationTokens.regular;
}
