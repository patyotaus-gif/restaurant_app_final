import 'dart:math' as math;

import 'package:flutter/material.dart';

class ResponsiveTokens {
  const ResponsiveTokens._(this._size);

  factory ResponsiveTokens.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return ResponsiveTokens._(size);
  }

  final Size _size;

  static const EdgeInsets edgeInsetsSmall = EdgeInsets.all(12);

  double get overlayWidth {
    final width = _size.width;
    if (width >= 1440) {
      return 420;
    }
    if (width >= 1024) {
      return 360;
    }
    if (width >= 600) {
      return 320;
    }
    return math.max(240, width - 48);
  }

  EdgeInsets get paddingMedium => const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      );

  double get radiusMedium => 12;

  SizedBox get gapSmall => const SizedBox(width: 12);
}
