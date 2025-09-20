import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/role_permission_model.dart';
import '../models/store_model.dart';
import '../services/store_service.dart';
import '../stock_provider.dart';
import '../store_provider.dart';

class StoreManagementPage extends StatefulWidget {
  const StoreManagementPage({super.key});

  @override
  State<StoreManagementPage> createState() => _StoreManagementPageState();
}

class _StoreManagementPageState extends State<StoreManagementPage> {
  bool _isSaving = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final storeProvider = context.watch<StoreProvider>();
    final authService = context.watch<AuthService>();
    final storeService = context.read<StoreService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stores & Branches'),
        actions: [
          IconButton(
            onPressed: () async {
              await storeProvider.refreshRoleOverrides();
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Role definitions refreshed.')),
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload role definitions',
          ),
        ],
      ),
      floatingActionButton: authService.hasPermission(Permission.manageStores)
          ? FloatingActionButton.extended(
              onPressed: () => _showCreateStoreDialog(context, storeService),
              icon: const Icon(Icons.add_business),
              label: const Text('Add Store'),
            )
          : null,
      body: Column(
        children: [
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildStoresCard(
                    context,
                    storeProvider,
                    authService,
                    storeService,
                  ),
                ),
                Expanded(child: _buildRoleCard()),
              ],
            ),
          ),
          if (_isSaving) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Widget _buildStoresCard(
    BuildContext context,
    StoreProvider storeProvider,
    AuthService authService,
    StoreService storeService,
  ) {
    final stores = storeProvider.stores;
    final active = storeProvider.activeStore;
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.store_mall_directory),
                const SizedBox(width: 8),
                const Text(
                  'Stores',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (authService.hasPermission(Permission.manageStores))
                  TextButton.icon(
                    onPressed: () =>
                        _showCreateStoreDialog(context, storeService),
                    icon: const Icon(Icons.add),
                    label: const Text('New store'),
                  ),
              ],
            ),
            const Divider(),
            if (storeProvider.isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator()))
            else if (stores.isEmpty)
              const Expanded(
                child: Center(
                  child: Text(
                    'No stores available. Contact your administrator.',
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: stores.length,
                  itemBuilder: (context, index) {
                    final store = stores[index];
                    final isActive = store.id == active?.id;
                    return ListTile(
                      leading: Icon(
                        Icons.location_on_outlined,
                        color: isActive
                            ? Theme.of(context).colorScheme.primary
                            : null,
                      ),
                      title: Text(store.name),
                      subtitle: store.address != null
                          ? Text(store.address!)
                          : null,
                      trailing: isActive
                          ? Chip(
                              label: const Text('Active'),
                              backgroundColor: Theme.of(
                                context,
                              ).colorScheme.primaryContainer,
                            )
                          : null,
                      onTap: () {
                        storeProvider.setActiveStore(store, authService);
                        context.read<StockProvider>().setActiveStore(store.id);
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCard() {
    final roleSnapshot = RolePermissionRegistry.snapshot();
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.security),
                SizedBox(width: 8),
                Text(
                  'Roles & Permissions',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView(
                children: roleSnapshot.entries.map((entry) {
                  return ListTile(
                    title: Text(entry.key.toUpperCase()),
                    subtitle: Text(entry.value.map((e) => e.name).join(', ')),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateStoreDialog(
    BuildContext context,
    StoreService storeService,
  ) async {
    final nameController = TextEditingController();
    final addressController = TextEditingController();
    final timezoneController = TextEditingController();

    final shouldSave = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create store'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Store name'),
                ),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                TextField(
                  controller: timezoneController,
                  decoration: const InputDecoration(
                    labelText: 'Timezone (optional)',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (shouldSave != true) {
      return;
    }

    if (nameController.text.trim().isEmpty) {
      setState(() {
        _errorMessage = 'Store name is required';
      });
      return;
    }

    setState(() {
      _errorMessage = null;
      _isSaving = true;
    });

    try {
      final store = Store(
        id: '',
        name: nameController.text.trim(),
        address: addressController.text.trim().isEmpty
            ? null
            : addressController.text.trim(),
        timezone: timezoneController.text.trim().isEmpty
            ? null
            : timezoneController.text.trim(),
      );
      await storeService.saveStore(store);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Store "${store.name}" created.')));
    } catch (error) {
      setState(() {
        _errorMessage = 'Failed to create store: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
