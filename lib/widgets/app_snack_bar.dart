import 'package:flutter/material.dart';

enum AppSnackBarType { info, success, warning, error }

class AppSnackBar {
  AppSnackBar._();

  static final messengerKey = GlobalKey<ScaffoldMessengerState>();

  static void show(
    String message, {
    AppSnackBarType type = AppSnackBarType.info,
    VoidCallback? onUndo,
    String? undoLabel,
    Duration duration = const Duration(seconds: 4),
  }) {
    final messenger = messengerKey.currentState;
    if (messenger == null) {
      return;
    }

    final theme = Theme.of(messenger.context);
    final colorScheme = theme.colorScheme;

    Color? background;
    Color? textColor;

    switch (type) {
      case AppSnackBarType.info:
        background = colorScheme.inverseSurface;
        textColor = colorScheme.onInverseSurface;
        break;
      case AppSnackBarType.success:
        background = colorScheme.tertiaryContainer;
        textColor = colorScheme.onTertiaryContainer;
        break;
      case AppSnackBarType.warning:
        background = colorScheme.errorContainer;
        textColor = colorScheme.onErrorContainer;
        break;
      case AppSnackBarType.error:
        background = colorScheme.error;
        textColor = colorScheme.onError;
        break;
    }

    messenger
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
          ),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
          duration: duration,
          action: onUndo != null
              ? SnackBarAction(
                  label: undoLabel ?? 'Undo',
                  onPressed: onUndo,
                )
              : null,
        ),
      );
  }

  static void showSuccess(String message, {VoidCallback? onUndo, String? undoLabel}) {
    show(
      message,
      type: AppSnackBarType.success,
      onUndo: onUndo,
      undoLabel: undoLabel,
    );
  }

  static void showInfo(String message, {VoidCallback? onUndo, String? undoLabel}) {
    show(
      message,
      type: AppSnackBarType.info,
      onUndo: onUndo,
      undoLabel: undoLabel,
    );
  }

  static void showError(String message) {
    show(
      message,
      type: AppSnackBarType.error,
      duration: const Duration(seconds: 6),
    );
  }
}
