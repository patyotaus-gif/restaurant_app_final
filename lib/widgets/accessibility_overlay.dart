import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../accessibility_provider.dart';
import 'responsive/responsive_tokens.dart';

class AccessibilityOverlayHost extends StatefulWidget {
  const AccessibilityOverlayHost({required this.child, super.key});

  final Widget child;

  @override
  State<AccessibilityOverlayHost> createState() => _AccessibilityOverlayHostState();
}

class _AccessibilityOverlayHostState extends State<AccessibilityOverlayHost> {
  bool _panelVisible = false;

  void _togglePanel() {
    setState(() {
      _panelVisible = !_panelVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        Align(
          alignment: Alignment.bottomLeft,
          child: SafeArea(
            minimum: ResponsiveTokens.edgeInsetsSmall,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_panelVisible)
                  _AccessibilityPanel(onClose: _togglePanel),
                FloatingActionButton.small(
                  heroTag: '_a11y_toggle',
                  onPressed: _togglePanel,
                  tooltip: 'Accessibility',
                  child: Icon(_panelVisible ? Icons.visibility_off : Icons.visibility),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AccessibilityPanel extends StatelessWidget {
  const _AccessibilityPanel({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = ResponsiveTokens.of(context);
    final accessibility = context.watch<AccessibilityProvider>();
    final theme = Theme.of(context);

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: tokens.overlayWidth,
      ),
      child: Material(
        elevation: 6,
        borderRadius: BorderRadius.circular(tokens.radiusMedium),
        clipBehavior: Clip.antiAlias,
        color: theme.colorScheme.surface,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              color: theme.colorScheme.primaryContainer,
              padding: tokens.paddingMedium,
              child: Row(
                children: [
                  Icon(Icons.accessibility_new, color: theme.colorScheme.onPrimaryContainer),
                  tokens.gapSmall,
                  Expanded(
                    child: Text(
                      'Accessibility',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Padding(
              padding: tokens.paddingMedium,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: accessibility.largeText,
                    onChanged: (value) => accessibility.setLargeText(value),
                    title: const Text('Large text'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  SwitchListTile(
                    value: accessibility.highContrast,
                    onChanged: (value) => accessibility.setHighContrast(value),
                    title: const Text('High contrast mode'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
