import 'package:flutter/material.dart';

/// A responsive scaffold that adapts the primary navigation pattern
/// based on the available width.
///
/// * Compact layouts (< 600px) use a [NavigationBar] at the bottom.
/// * Medium layouts (>= 600px and < 1024px) use a [NavigationRail].
/// * Expanded layouts (>= 1024px) use a persistent [NavigationDrawer].
class ResponsiveScaffold extends StatelessWidget {
  const ResponsiveScaffold({
    super.key,
    required this.body,
    required this.destinations,
    required this.selectedIndex,
    required this.onDestinationSelected,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
  });

  final Widget body;
  final List<NavigationDestination> destinations;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;

  static const double _compactBreakpoint = 600;
  static const double _mediumBreakpoint = 1024;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    if (width < _compactBreakpoint) {
      return _buildBottomNavigationScaffold(context);
    }

    if (width < _mediumBreakpoint) {
      return _buildNavigationRailScaffold(context);
    }

    return _buildPersistentNavigationScaffold(context);
  }

  Widget _buildBottomNavigationScaffold(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      body: body,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex,
        destinations: destinations,
        onDestinationSelected: onDestinationSelected,
      ),
    );
  }

  Widget _buildNavigationRailScaffold(BuildContext context) {
    final railDestinations = destinations
        .map(
          (destination) => NavigationRailDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon ?? destination.icon,
            label: Text(destination.label),
          ),
        )
        .toList();

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Row(
        children: [
          SafeArea(
            child: NavigationRail(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              destinations: railDestinations,
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }

  Widget _buildPersistentNavigationScaffold(BuildContext context) {
    final drawerDestinations = destinations
        .map(
          (destination) => NavigationDrawerDestination(
            icon: destination.icon,
            selectedIcon: destination.selectedIcon ?? destination.icon,
            label: Text(destination.label),
          ),
        )
        .toList();

    return Scaffold(
      appBar: appBar,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      body: Row(
        children: [
          SafeArea(
            child: NavigationDrawer(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              children: [
                const SizedBox(height: 12),
                ...drawerDestinations,
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: body),
        ],
      ),
    );
  }
}
