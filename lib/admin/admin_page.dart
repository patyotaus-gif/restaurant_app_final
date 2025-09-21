// lib/admin/admin_page.dart
import 'package:provider/provider.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:badges/badges.dart' as badges;
import '../stock_provider.dart';
import '../theme_provider.dart';
import '../add_expense_page.dart';
import '../qr_generator_page.dart';
import '../models/app_mode.dart';
import '../app_mode_provider.dart';

class AdminPage extends StatelessWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final stockProvider = Provider.of<StockProvider>(context);
    final appModeProvider = Provider.of<AppModeProvider>(context);

    final lowStockCount = stockProvider.lowStockIngredients.length;
    final currentMode = appModeProvider.appMode;

    // --- Responsive Logic ---
    final screenWidth = MediaQuery.of(context).size.width;
    final int crossAxisCount;
    final double childAspectRatio;

    if (screenWidth < 600) {
      // Mobile layout
      crossAxisCount = 2;
      childAspectRatio = 1.0;
    } else if (screenWidth < 1200) {
      // Tablet layout
      crossAxisCount = 3;
      childAspectRatio = 1.1;
    } else {
      // Desktop layout
      crossAxisCount = 4;
      childAspectRatio = 1.0;
    }
    // --------------------

    final List<Map<String, dynamic>> allAdminMenuItems = [
      {
        'title': 'Low Stock Alerts',
        'subtitle': 'View items that need reordering',
        'icon': Icons.warning_amber_rounded,
        'route': '/admin/low-stock-alerts',
        'isSpecial': true,
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Table Reservations',
        'subtitle': 'Manage customer bookings',
        'icon': Icons.calendar_month_outlined,
        'route': '/admin/reservations',
        'modes': [AppMode.restaurant],
      },
      {
        'title': 'Employee Management',
        'subtitle': 'Manage staff, roles, and PINs',
        'icon': Icons.people_alt_outlined,
        'route': '/admin/employees',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Time Clock Report',
        'subtitle': 'View staff work hours',
        'icon': Icons.access_time_filled,
        'route': '/admin/time-report',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Promotion Management',
        'subtitle': 'Create and manage discount codes',
        'icon': Icons.local_offer_outlined,
        'route': '/admin/promotions',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Punch Cards',
        'subtitle': 'Manage loyalty punch cards',
        'icon': Icons.card_giftcard,
        'route': '/admin/punch-cards',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      // --- ADDED THIS NEW MENU ITEM ---
      {
        'title': 'Manage Modifiers',
        'subtitle': 'Manage product options and combos',
        'icon': Icons.add_link,
        'route': '/admin/modifiers',
        'modes': [AppMode.restaurant],
      },
      // ---------------------------------
      {
        'title': 'Manage Products',
        'subtitle': 'Add, edit, or delete items',
        'icon': Icons.style_outlined,
        'route': '/admin/products',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Supplier Management',
        'subtitle': 'Manage suppliers and contacts',
        'icon': Icons.groups_outlined,
        'route': '/admin/suppliers',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Purchase Orders',
        'subtitle': 'Order stock from suppliers',
        'icon': Icons.receipt_long_outlined,
        'route': '/admin/purchase-orders',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Manage Inventory',
        'subtitle': 'Manage ingredients and stock levels',
        'icon': Icons.inventory_2_outlined,
        'route': '/admin/inventory',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Waste Tracking',
        'subtitle': 'Record expired or damaged stock',
        'icon': Icons.delete_sweep_outlined,
        'route': '/admin/waste',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Sales Dashboard',
        'subtitle': 'View sales and reports',
        'icon': Icons.dashboard_outlined,
        'route': '/admin/dashboard',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Analytics & CRM',
        'subtitle': 'BigQuery export and RFM scoring',
        'icon': Icons.analytics_outlined,
        'route': '/admin/analytics',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'End of Day Report',
        'subtitle': 'Close out and view final numbers',
        'icon': Icons.assessment_outlined,
        'route': '/admin/eod',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Accounting Export',
        'subtitle': 'Export data to CSV files',
        'icon': Icons.upload_file_outlined,
        'route': '/admin/accounting-export',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Kitchen Display System',
        'subtitle': 'View active kitchen orders',
        'icon': Icons.kitchen_outlined,
        'route': '/admin/kds',
        'modes': [AppMode.restaurant],
      },
      {
        'title': 'Record Expense',
        'subtitle': 'Log other business costs',
        'icon': Icons.payment_outlined,
        'route': 'add_expense_page',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
      {
        'title': 'Generate QR Code',
        'subtitle': 'For customer self-ordering',
        'icon': Icons.qr_code_scanner_outlined,
        'route': 'qr_generator_page',
        'modes': [AppMode.restaurant],
      },
      {
        'title': 'Dark Mode',
        'subtitle': 'Toggle UI theme',
        'icon': Icons.brightness_6_outlined,
        'route': 'toggle_dark_mode',
        'modes': [AppMode.restaurant, AppMode.retail],
      },
    ];

    final filteredMenuItems = allAdminMenuItems.where((item) {
      final modes = item['modes'] as List<AppMode>;
      return modes.contains(currentMode);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Panel'),
        backgroundColor: Colors.indigo,
      ),
      body: GridView.builder(
        padding: const EdgeInsets.all(16.0),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: childAspectRatio,
        ),
        itemCount: filteredMenuItems.length,
        itemBuilder: (context, index) {
          final item = filteredMenuItems[index];

          if (item['route'] == 'toggle_dark_mode') {
            return Consumer<ThemeProvider>(
              builder: (context, themeProvider, child) {
                return _AdminMenuCard(
                  title: item['title'],
                  subtitle: item['subtitle'],
                  icon: item['icon'],
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

          return badges.Badge(
            showBadge: item['isSpecial'] == true && lowStockCount > 0,
            badgeContent: Text(
              lowStockCount.toString(),
              style: const TextStyle(color: Colors.white),
            ),
            position: badges.BadgePosition.topEnd(top: 8, end: 8),
            child: _AdminMenuCard(
              title: item['title'],
              subtitle: item['subtitle'],
              icon: item['icon'],
              isSpecial: item['isSpecial'] ?? false,
              onTap: () {
                if (item['route'] == 'add_expense_page') {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (ctx) => const AddExpensePage()),
                  );
                } else if (item['route'] == 'qr_generator_page') {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (ctx) => const QrGeneratorPage(),
                    ),
                  );
                } else {
                  context.push(item['route']);
                }
              },
            ),
          );
        },
      ),
    );
  }
}

class _AdminMenuCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool isSpecial;
  final Widget? trailingWidget;

  const _AdminMenuCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.isSpecial = false,
    this.trailingWidget,
  });

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
