// lib/order_type_selection_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'app_mode_provider.dart';
import 'auth_service.dart';
class OrderTypeSelectionPage extends StatelessWidget {
  const OrderTypeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppModeProvider>(
      builder: (context, appModeProvider, child) {
        if (appModeProvider.isLoading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final isRestaurantMode = appModeProvider.appMode == AppMode.restaurant;

        return Scaffold(
          appBar: AppBar(
            title: Text(isRestaurantMode ? 'Restaurant Mode' : 'Retail Mode'),
            backgroundColor: Colors.indigo,
            automaticallyImplyLeading: false,
            actions: [
              // --- ADDED: Clock In/Out Button ---
              IconButton(
                icon: const Icon(Icons.timer_outlined),
                tooltip: 'Clock In/Out',
                onPressed: () {
                  context.push('/clock-in-out');
                },
              ),
              IconButton(
                icon: const Icon(Icons.admin_panel_settings),
                tooltip: 'Admin Panel',
                onPressed: () {
                  context.push('/admin');
                },
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                tooltip: 'Logout',
                onPressed: () async {
                  final authService = Provider.of<AuthService>(
                    context,
                    listen: false,
                  );
                  await authService.signOut();
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
              ),
            ],
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: isRestaurantMode
                  ? _buildRestaurantOptions(context)
                  : _buildRetailOptions(context),
            ),
          ),
          bottomNavigationBar: BottomAppBar(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Restaurant'),
                  Switch(
                    value: !isRestaurantMode,
                    onChanged: (value) {
                      final newMode = value
                          ? AppMode.retail
                          : AppMode.restaurant;
                      appModeProvider.setAppMode(newMode);
                    },
                  ),
                  const Text('Retail'),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantOptions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTypeButton(
          context: context,
          icon: Icons.restaurant,
          label: 'Dine-In',
          onPressed: () => context.go('/floorplan'),
        ),
        _buildTypeButton(
          context: context,
          icon: Icons.takeout_dining,
          label: 'Takeaway',
          onPressed: () => context.go('/takeaway-orders'),
        ),
      ],
    );
  }

  Widget _buildRetailOptions(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildTypeButton(
          context: context,
          icon: Icons.point_of_sale,
          label: 'New Sale',
          onPressed: () => context.push('/retail-pos'),
        ),
        _buildTypeButton(
          context: context,
          icon: Icons.inventory,
          label: 'Products',
          onPressed: () => context.push('/admin/products'),
        ),
      ],
    );
  }

  Widget _buildTypeButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Expanded(
      child: AspectRatio(
        aspectRatio: 1,
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ElevatedButton(
            onPressed: onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(16),
              elevation: 8,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 48),
                const SizedBox(height: 12),
                FittedBox(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
