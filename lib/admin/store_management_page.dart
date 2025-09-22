import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../feature_flags/feature_flag_provider.dart';
import '../feature_flags/feature_flag_scope.dart';
import '../feature_flags/terminal_provider.dart';
import '../models/role_permission_model.dart';
import '../models/store_model.dart';
import 'plugins/plugin_provider.dart';
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
  final TextEditingController _flagNameController = TextEditingController();
  final TextEditingController _terminalIdController = TextEditingController();
  FeatureFlagScope _selectedScope = FeatureFlagScope.tenant;
  bool _flagValue = true;

  @override
  void dispose() {
    _flagNameController.dispose();
    _terminalIdController.dispose();
    super.dispose();
  }

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
                  flex: 3,
                  child: _buildStoresCard(
                    context,
                    storeProvider,
                    authService,
                    storeService,
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      Expanded(child: _buildPluginCard(context, authService)),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _buildFeatureFlagCard(
                          context,
                          storeProvider,
                          authService,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(flex: 3, child: _buildRoleCard()),
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

  Widget _buildPluginCard(BuildContext context, AuthService authService) {
    final pluginProvider = context.watch<PluginProvider>();
    final store = pluginProvider.activeStore;
    final modules = pluginProvider.availableModules.toList();
    final canManage = authService.hasPermission(Permission.manageStores);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.extension),
                SizedBox(width: 8),
                Text(
                  'Store Plugins',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (store == null)
              const Expanded(
                child: Center(child: Text('Select a store to manage plugins.')),
              )
            else if (modules.isEmpty)
              const Expanded(
                child: Center(
                  child: Text('No plugins are registered for this deployment.'),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  itemCount: modules.length,
                  itemBuilder: (context, index) {
                    final module = modules[index];
                    final isEnabled = pluginProvider.isEnabled(module.id);
                    return SwitchListTile.adaptive(
                      value: isEnabled,
                      title: Text(module.name),
                      subtitle: Text(module.description),
                      onChanged: canManage
                          ? (value) async {
                              try {
                                await pluginProvider.setPluginState(
                                  module.id,
                                  value,
                                );
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '"${module.name}" ${value ? 'enabled' : 'disabled'} for ${store.name}.',
                                    ),
                                  ),
                                );
                              } catch (error) {
                                if (!mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to update plugin: $error',
                                    ),
                                    backgroundColor: Theme.of(
                                      context,
                                    ).colorScheme.error,
                                  ),
                                );
                              }
                            }
                          : null,
                    );
                  },
                ),
              ),
            if (!canManage)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'You do not have permission to modify plugin availability.',
                  style: TextStyle(fontStyle: FontStyle.italic),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureFlagCard(
    BuildContext context,
    StoreProvider storeProvider,
    AuthService authService,
  ) {
    final featureFlagProvider = context.watch<FeatureFlagProvider>();
    final terminalProvider = context.watch<TerminalProvider>();
    final store = storeProvider.activeStore;
    final flags = featureFlagProvider.activeFlags.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final terminalId = terminalProvider.terminalId ?? '';
    if (_terminalIdController.text != terminalId) {
      _terminalIdController.value = TextEditingValue(
        text: terminalId,
        selection: TextSelection.collapsed(offset: terminalId.length),
      );
    }

    final canManage = authService.hasPermission(Permission.manageStores);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.flag),
                SizedBox(width: 8),
                Text(
                  'Feature Flags',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            if (store == null)
              const Expanded(
                child: Center(
                  child: Text('Select a store to inspect feature flags.'),
                ),
              )
            else ...[
              Text('Tenant: ${store.tenantId}'),
              Text('Store: ${store.name} (${store.id})'),
              const SizedBox(height: 8),
              TextField(
                controller: _terminalIdController,
                decoration: InputDecoration(
                  labelText: 'Terminal identifier',
                  helperText:
                      'Terminal-scoped flags will apply to this identifier.',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.save),
                    tooltip: 'Persist terminal identifier',
                    onPressed: () => _persistTerminalId(context),
                  ),
                ),
                onSubmitted: (_) => _persistTerminalId(context),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: flags.isEmpty
                    ? const Center(
                        child: Text(
                          'No feature flags configured for this scope.',
                        ),
                      )
                    : ListView.builder(
                        itemCount: flags.length,
                        itemBuilder: (context, index) {
                          final entry = flags[index];
                          final isEnabled = entry.value;
                          return ListTile(
                            title: Text(entry.key),
                            trailing: Chip(
                              label: Text(isEnabled ? 'Enabled' : 'Disabled'),
                              backgroundColor: isEnabled
                                  ? Theme.of(
                                      context,
                                    ).colorScheme.primaryContainer
                                  : Theme.of(
                                      context,
                                    ).colorScheme.surfaceVariant,
                            ),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              if (canManage) _buildFlagComposer(context, store),
            ],
            if (!canManage)
              const Padding(
                padding: EdgeInsets.only(top: 8.0),
                child: Text(
                  'You do not have permission to set feature flags.',
                  style: TextStyle(fontStyle: FontStyle.italic),
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

  Widget _buildFlagComposer(BuildContext context, Store store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Create or override feature flag',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _flagNameController,
                decoration: const InputDecoration(
                  labelText: 'Flag key',
                  hintText: 'e.g. enableNewCheckout',
                ),
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<FeatureFlagScope>(
              value: _selectedScope,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedScope = value;
                });
              },
              items: FeatureFlagScope.values
                  .map(
                    (scope) => DropdownMenuItem(
                      value: scope,
                      child: Text(
                        scope.name[0].toUpperCase() + scope.name.substring(1),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Switch(
              value: _flagValue,
              onChanged: (value) {
                setState(() {
                  _flagValue = value;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(_flagValue ? 'Enabled' : 'Disabled'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _saveFlag(context, store),
              icon: const Icon(Icons.save),
              label: const Text('Save flag'),
            ),
          ],
        ),
        if (_selectedScope == FeatureFlagScope.store)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              'Store scoped flag for ${store.name} (${store.id}).',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_selectedScope == FeatureFlagScope.terminal)
          Padding(
            padding: const EdgeInsets.only(top: 8.0),
            child: Text(
              _terminalIdController.text.trim().isEmpty
                  ? 'Set a terminal identifier before saving a terminal scoped flag.'
                  : 'Terminal scoped flag for "${_terminalIdController.text.trim()}".',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }

  Future<void> _saveFlag(BuildContext context, Store store) async {
    final flagKey = _flagNameController.text.trim();
    if (flagKey.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a flag key.')));
      return;
    }

    final terminalId = _terminalIdController.text.trim();
    if (_selectedScope == FeatureFlagScope.terminal && terminalId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Provide a terminal identifier to save terminal flags.',
          ),
        ),
      );
      return;
    }

    final featureFlagProvider = context.read<FeatureFlagProvider>();
    try {
      await featureFlagProvider.setFlag(
        scope: _selectedScope,
        flag: flagKey,
        isEnabled: _flagValue,
        storeId: _selectedScope == FeatureFlagScope.store ? store.id : null,
        terminalId: _selectedScope == FeatureFlagScope.terminal
            ? terminalId
            : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Flag "$flagKey" ${_flagValue ? 'enabled' : 'disabled'} at ${_selectedScope.name} scope.',
          ),
        ),
      );
      _flagNameController.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update feature flag: $error'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  Future<void> _persistTerminalId(BuildContext context) async {
    final terminalProvider = context.read<TerminalProvider>();
    await terminalProvider.setTerminalId(_terminalIdController.text.trim());
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Terminal identifier saved for this device.'),
      ),
    );
  }
}
