// lib/admin/admin_page.dart
import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../add_expense_page.dart';
import '../app_mode_provider.dart';
import '../qr_generator_page.dart';
import '../stock_provider.dart';
import '../theme_provider.dart';
import '../widgets/responsive_scaffold.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  int _selectedCategoryIndex = 0;

  static final List<_AdminMenuItem> _allMenuItems = [
    _AdminMenuItem(
      title: 'Low Stock Alerts',
      subtitle: 'View items that need reordering',
      icon: Icons.warning_amber_rounded,
      route: '/admin/low-stock-alerts',
      isSpecial: true,
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
      showLowStockBadge: true,
    ),
    _AdminMenuItem(
      title: 'Table Reservations',
      subtitle: 'Manage customer bookings',
      icon: Icons.calendar_month_outlined,
      route: '/admin/reservations',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant],
    ),
    _AdminMenuItem(
      title: 'Employee Management',
      subtitle: 'Manage staff, roles, and PINs',
      icon: Icons.people_alt_outlined,
      route: '/admin/employees',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Time Clock Report',
      subtitle: 'View staff work hours',
      icon: Icons.access_time_filled,
      route: '/admin/time-report',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Promotion Management',
      subtitle: 'Create and manage discount codes',
      icon: Icons.local_offer_outlined,
      route: '/admin/promotions',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Backoffice Designer',
      subtitle: 'Build schema-driven workflows and forms',
      icon: Icons.auto_awesome_mosaic_outlined,
      route: '/admin/schema-designer',
      category: _AdminCategory.tools,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Punch Cards',
      subtitle: 'Manage loyalty punch cards',
      icon: Icons.card_giftcard,
      route: '/admin/punch-cards',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'QA Playbooks',
      subtitle: 'Runbooks for on-call and QA sign-off',
      icon: Icons.fact_check_outlined,
      route: '/admin/qa-playbooks',
      category: _AdminCategory.tools,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Ops Observability',
      subtitle: 'Inspect logs & platform health signals',
      icon: Icons.monitor_heart_outlined,
      route: '/admin/observability',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Manage Modifiers',
      subtitle: 'Manage product options and combos',
      icon: Icons.add_link,
      route: '/admin/modifiers',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant],
    ),
    _AdminMenuItem(
      title: 'Manage Products',
      subtitle: 'Add, edit, or delete items',
      icon: Icons.style_outlined,
      route: '/admin/products',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Supplier Management',
      subtitle: 'Manage suppliers and contacts',
      icon: Icons.groups_outlined,
      route: '/admin/suppliers',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Purchase Orders',
      subtitle: 'Order stock from suppliers',
      icon: Icons.receipt_long_outlined,
      route: '/admin/purchase-orders',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Stocktake & Adjustments',
      subtitle: 'Scan inventory and record counts',
      icon: Icons.qr_code_2_outlined,
      route: '/admin/stocktake',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Manage Inventory',
      subtitle: 'Manage ingredients and stock levels',
      icon: Icons.inventory_2_outlined,
      route: '/admin/inventory',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Waste Tracking',
      subtitle: 'Record expired or damaged stock',
      icon: Icons.delete_sweep_outlined,
      route: '/admin/waste',
      category: _AdminCategory.inventory,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Sales Dashboard',
      subtitle: 'View sales and reports',
      icon: Icons.dashboard_outlined,
      route: '/admin/dashboard',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Analytics & CRM',
      subtitle: 'BigQuery export and RFM scoring',
      icon: Icons.analytics_outlined,
      route: '/admin/analytics',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'End of Day Report',
      subtitle: 'Close out and view final numbers',
      icon: Icons.assessment_outlined,
      route: '/admin/eod',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Accounting Export',
      subtitle: 'Export data to CSV files',
      icon: Icons.upload_file_outlined,
      route: '/admin/accounting-export',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Branch Management',
      subtitle: 'Manage stores and staff permissions',
      icon: Icons.store_mall_directory_outlined,
      route: '/admin/stores',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Kitchen Display System',
      subtitle: 'View active kitchen orders',
      icon: Icons.kitchen_outlined,
      route: '/admin/kds',
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant],
    ),
    _AdminMenuItem(
      title: 'Audit Trail',
      subtitle: 'Review inventory & staff activity',
      icon: Icons.policy_outlined,
      route: '/admin/audit-log',
      category: _AdminCategory.insights,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Record Expense',
      subtitle: 'Log other business costs',
      icon: Icons.payment_outlined,
      pageBuilder: (_) => const AddExpensePage(),
      category: _AdminCategory.operations,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
    _AdminMenuItem(
      title: 'Generate QR Code',
      subtitle: 'For customer self-ordering',
      icon: Icons.qr_code_scanner_outlined,
      pageBuilder: (_) => const QrGeneratorPage(),
      category: _AdminCategory.tools,
      modes: const [AppMode.restaurant],
    ),
    _AdminMenuItem(
      title: 'Dark Mode',
      subtitle: 'Toggle UI theme',
      icon: Icons.brightness_6_outlined,
      isThemeToggle: true,
      category: _AdminCategory.tools,
      modes: const [AppMode.restaurant, AppMode.retail],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final lowStockCount = context.watch<StockProvider>().lowStockIngredients.length;
    final currentMode = context.watch<AppModeProvider>().appMode;
    final selectedCategory = _AdminCategory.values[_selectedCategoryIndex];

    final menuItems = _allMenuItems
        .where(
          (item) =>
              item.category == selectedCategory &&
              item.modes.contains(currentMode),
        )
        .toList();

    return ResponsiveScaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.indigo,
      ),
      destinations: _AdminCategory.values
          .map(
            (category) => NavigationDestination(
              icon: Icon(category.icon),
              label: category.label,
            ),
          )
          .toList(),
      selectedIndex: _selectedCategoryIndex,
      onDestinationSelected: (index) {
        setState(() => _selectedCategoryIndex = index);
      },
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final metrics = _GridMetrics.fromWidth(constraints.maxWidth);

            if (menuItems.isEmpty) {
              return Center(
                child: Text(
                  'No tools available for this category yet.',
                  style: Theme.of(context).textTheme.bodyLarge,
                  textAlign: TextAlign.center,
                ),
              );
            }

            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: metrics.crossAxisCount,
                childAspectRatio: metrics.childAspectRatio,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
              ),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuCard(context, item, lowStockCount);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context,
    _AdminMenuItem item,
    int lowStockCount,
  ) {
    if (item.isThemeToggle) {
      return Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return _AdminMenuCard(
            title: item.title,
            subtitle: item.subtitle,
            icon: item.icon,
            onTap: () {},
            trailingWidget: Switch(
              value: themeProvider.themeMode == ThemeMode.dark,
              onChanged: (value) {
                themeProvider.setTheme(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          );
        },
      );
    }

    final card = _AdminMenuCard(
      title: item.title,
      subtitle: item.subtitle,
      icon: item.icon,
      isSpecial: item.isSpecial,
      onTap: () => _handleMenuTap(context, item),
    );

    if (item.showLowStockBadge && lowStockCount > 0) {
      return badges.Badge(
        position: badges.BadgePosition.topEnd(top: 8, end: 8),
        badgeContent: Text(
          '$lowStockCount',
          style: const TextStyle(color: Colors.white),
        ),
        child: card,
      );
    }

    return card;
  }

  void _handleMenuTap(BuildContext context, _AdminMenuItem item) {
    if (!mounted) return;
    if (item.pageBuilder != null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: item.pageBuilder!),
      );
      return;
    }

    if (item.route != null) {
      context.push(item.route!);
    }
  }
}

class _GridMetrics {
  const _GridMetrics({required this.crossAxisCount, required this.childAspectRatio});

  final int crossAxisCount;
  final double childAspectRatio;

  static _GridMetrics fromWidth(double width) {
    if (width < 600) {
      return const _GridMetrics(crossAxisCount: 2, childAspectRatio: 1.0);
    }
    if (width < 1200) {
      return const _GridMetrics(crossAxisCount: 3, childAspectRatio: 1.1);
    }
    return const _GridMetrics(crossAxisCount: 4, childAspectRatio: 1.0);
  }
}

enum _AdminCategory { operations, inventory, insights, tools }

extension on _AdminCategory {
  String get label {
    switch (this) {
      case _AdminCategory.operations:
        return 'Operations';
      case _AdminCategory.inventory:
        return 'Inventory';
      case _AdminCategory.insights:
        return 'Insights';
      case _AdminCategory.tools:
        return 'Tools';
    }
  }

  IconData get icon {
    switch (this) {
      case _AdminCategory.operations:
        return Icons.dashboard_customize_outlined;
      case _AdminCategory.inventory:
        return Icons.inventory_2_outlined;
      case _AdminCategory.insights:
        return Icons.insights_outlined;
      case _AdminCategory.tools:
        return Icons.build_outlined;
    }
  }
}

class _AdminMenuItem {
  const _AdminMenuItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.modes,
    this.route,
    this.pageBuilder,
    this.isSpecial = false,
    this.isThemeToggle = false,
    this.showLowStockBadge = false,
  }) : assert(
            (route != null ? 1 : 0) +
                    (pageBuilder != null ? 1 : 0) +
                    (isThemeToggle ? 1 : 0) ==
                1,
          );

  final String title;
  final String subtitle;
  final IconData icon;
  final _AdminCategory category;
  final List<AppMode> modes;
  final String? route;
  final WidgetBuilder? pageBuilder;
  final bool isSpecial;
  final bool isThemeToggle;
  final bool showLowStockBadge;
}

class _AdminMenuCard extends StatelessWidget {
  const _AdminMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isSpecial = false,
    this.trailingWidget,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSpecial;
  final Widget? trailingWidget;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      color: isSpecial ? Colors.red.shade50 : null,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                icon,
                size: 32,
                color: isSpecial
                    ? Colors.red.shade700
                    : Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: isSpecial ? Colors.red.shade900 : null,
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              if (trailingWidget != null) trailingWidget!,
            ],
          ),
        ),
      ),
    );
  }
}
