import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart';
import '../currency_provider.dart';
import '../feature_flags/feature_flag_provider.dart';
import '../feature_flags/feature_flag_scope.dart';
import '../feature_flags/terminal_provider.dart';
import '../security/permission_policy.dart';
import '../services/store_service.dart';
import '../stock_provider.dart';
import '../store_provider.dart';
import '../widgets/permission_gate.dart';
import 'plugins/plugin_provider.dart';

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
  bool _isUpdatingCurrency = false;

  static const List<String> _commonCurrencies = [
    'THB',
    'USD',
    'EUR',
    'GBP',
    'JPY',
    'AUD',
    'CAD',
    'CNY',
    'HKD',
    'SGD',
    'MYR',
    'IDR',
    'PHP',
    'VND',
    'INR',
    'KRW',
    'CHF',
  ];

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
    final currencyProvider = context.watch<CurrencyProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Stores & Branches'),
        actions: [
          IconButton(
            onPressed: () async {
              await storeProvider.refreshRoleOverrides();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Role definitions refreshed.')),
              );
            },
            icon: const Icon(Icons.refresh),
            tooltip: 'Reload role definitions',
          ),
        ],
      ),
      floatingActionButton: PermissionGate(
        policy: PermissionPolicy.require(Permission.manageStores),
        builder: (_) => FloatingActionButton.extended(
          onPressed: () => _showCreateStoreDialog(context, storeService),
          icon: const Icon(Icons.add_business),
          label: const Text('Add Store'),
        ),
      ),
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
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      Expanded(
                        child: _buildCurrencyCard(
                          context,
                          storeProvider,
                          storeService,
                          currencyProvider,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(child: _buildRoleCard()),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (_isSaving || _isUpdatingCurrency)
            const LinearProgressIndicator(minHeight: 2),
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
                PermissionGate(
                  policy: PermissionPolicy.require(Permission.manageStores),
                  builder: (_) => TextButton.icon(
                    onPressed: () =>
                        _showCreateStoreDialog(context, storeService),
                    icon: const Icon(Icons.add),
                    label: const Text('New store'),
                  ),
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
    final permissionContext = PermissionContext(
      authService: authService,
      storeProvider: context.read<StoreProvider>(),
    );
    final canManage = PermissionPolicy.require(
      Permission.manageStores,
    ).evaluate(permissionContext);

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
                              if (!mounted) return;
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

    final permissionContext = PermissionContext(
      authService: authService,
      storeProvider: storeProvider,
    );
    final canManage = PermissionPolicy.require(
      Permission.manageStores,
    ).evaluate(permissionContext);

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
                                    ).colorScheme.surfaceContainerHighest,
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

  Widget _buildCurrencyCard(
    BuildContext context,
    StoreProvider storeProvider,
    StoreService storeService,
    CurrencyProvider currencyProvider,
  ) {
    final store = storeProvider.activeStore;
    if (store == null) {
      return const Card(
        margin: EdgeInsets.all(16),
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Select a store to configure currency preferences.'),
          ),
        ),
      );
    }

    final settings = store.currencySettings;
    final baseCurrency = settings.baseCurrency.toUpperCase();
    final supported = settings.normalizedSupportedCurrencies;
    final displayCurrency = settings.effectiveDisplayCurrency;
    final rates = currencyProvider.quotedRates;
    final rateEntries = supported
        .where((code) => code != baseCurrency)
        .map((code) => MapEntry(code, rates[code] ?? 0))
        .toList();
    final lastSynced = currencyProvider.lastSynced;
    final dateFormatter = DateFormat('dd MMM yyyy HH:mm');

    final baseOptions = {..._commonCurrencies, ...supported}.toList()..sort();

    final permissionContext = PermissionContext(
      authService: context.read<AuthService>(),
      storeProvider: storeProvider,
    );
    final canManage = PermissionPolicy.require(
      Permission.manageStores,
    ).evaluate(permissionContext);

    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.currency_exchange),
                SizedBox(width: 8),
                Text(
                  'Currency & FX Rates',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Base currency',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: baseCurrency,
                        items: baseOptions
                            .map(
                              (code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(code),
                              ),
                            )
                            .toList(),
                        onChanged: canManage
                            ? (value) {
                                if (value == null) return;
                                _onBaseCurrencyChanged(
                                  context,
                                  store,
                                  settings,
                                  value,
                                  storeService,
                                  currencyProvider,
                                );
                              }
                            : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Display currency',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      DropdownButtonFormField<String>(
                        initialValue: displayCurrency,
                        items: supported
                            .map(
                              (code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(code),
                              ),
                            )
                            .toList(),
                        onChanged: canManage
                            ? (value) {
                                if (value == null) return;
                                _updateDisplayCurrency(
                                  context,
                                  store,
                                  settings,
                                  value,
                                  storeService,
                                  currencyProvider,
                                );
                              }
                            : null,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'Supported currencies',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (canManage)
                  TextButton.icon(
                    onPressed: () => _showAddCurrencyDialog(
                      context,
                      store,
                      settings,
                      storeService,
                      currencyProvider,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Add currency'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: supported.map((code) {
                final isBase = code == baseCurrency;
                return InputChip(
                  label: Text(code),
                  onDeleted: canManage && !isBase
                      ? () => _removeCurrency(
                          context,
                          store,
                          settings,
                          code,
                          storeService,
                          currencyProvider,
                        )
                      : null,
                  deleteIcon: canManage && !isBase
                      ? const Icon(Icons.close)
                      : null,
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            const Text(
              'Daily FX rates',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: rateEntries.isEmpty
                  ? const Center(child: Text('No FX rates available.'))
                  : ListView.builder(
                      itemCount: rateEntries.length,
                      itemBuilder: (context, index) {
                        final entry = rateEntries[index];
                        final rate = entry.value;
                        return ListTile(
                          title: Text(entry.key),
                          subtitle: Text(
                            rate > 0
                                ? '1 $baseCurrency = '
                                      '${rate.toStringAsFixed(4)} ${entry.key}'
                                : 'No rate set for $baseCurrency → ${entry.key}',
                          ),
                          trailing: canManage
                              ? IconButton(
                                  tooltip: 'Update rate',
                                  icon: const Icon(Icons.edit_outlined),
                                  onPressed: () => _showUpdateRateDialog(
                                    context,
                                    store,
                                    settings,
                                    entry.key,
                                    rate > 0 ? rate : null,
                                    currencyProvider,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    lastSynced == null
                        ? 'Last synced: Never'
                        : 'Last synced: ${dateFormatter.format(lastSynced.toLocal())}',
                  ),
                ),
                if (canManage)
                  TextButton.icon(
                    onPressed: _isUpdatingCurrency
                        ? null
                        : () => _refreshFxRates(context, currencyProvider),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onBaseCurrencyChanged(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    String newBase,
    StoreService storeService,
    CurrencyProvider currencyProvider,
  ) async {
    final normalized = newBase.toUpperCase();
    final supported = settings.normalizedSupportedCurrencies;
    final updatedSupported = {...supported, normalized}.toList();
    final updatedSettings = settings.copyWith(
      baseCurrency: normalized,
      supportedCurrencies: updatedSupported,
      displayCurrency: settings.effectiveDisplayCurrency,
    );
    if (!mounted) return;
    await _persistCurrencySettings(
      context,
      store,
      updatedSettings,
      storeService,
      currencyProvider,
      successMessage: 'Base currency updated to $normalized.',
    );
  }

  Future<void> _updateDisplayCurrency(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    String displayCurrency,
    StoreService storeService,
    CurrencyProvider currencyProvider,
  ) async {
    final updatedSettings = settings.copyWith(
      displayCurrency: displayCurrency.toUpperCase(),
    );
    if (!mounted) return;
    await _persistCurrencySettings(
      context,
      store,
      updatedSettings,
      storeService,
      currencyProvider,
      successMessage:
          'Display currency updated to ${displayCurrency.toUpperCase()}.',
    );
  }

  Future<void> _showAddCurrencyDialog(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    StoreService storeService,
    CurrencyProvider currencyProvider,
  ) async {
    final existing = settings.normalizedSupportedCurrencies;
    final available =
        _commonCurrencies.where((code) => !existing.contains(code)).toList()
          ..sort();
    final manualController = TextEditingController();
    try {
      String? selected = available.isNotEmpty ? available.first : null;

      if (!mounted) return;
      final chosen = await showDialog<String>(
        context: context,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('Add supported currency'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (available.isNotEmpty)
                      DropdownButtonFormField<String>(
                        initialValue: selected,
                        decoration: const InputDecoration(
                          labelText: 'Common currencies',
                        ),
                        items: available
                            .map(
                              (code) => DropdownMenuItem<String>(
                                value: code,
                                child: Text(code),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          setState(() {
                            selected = value;
                          });
                        },
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: manualController,
                      textCapitalization: TextCapitalization.characters,
                      decoration: const InputDecoration(
                        labelText: 'ISO code',
                        hintText: 'e.g. USD',
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      final manual = manualController.text.trim().toUpperCase();
                      final resolved = manual.isNotEmpty
                          ? manual
                          : (selected?.toUpperCase() ?? '');
                      if (resolved.isEmpty) {
                        Navigator.of(context).pop();
                        return;
                      }
                      Navigator.of(context).pop(resolved);
                    },
                    child: const Text('Add'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (chosen == null || chosen.isEmpty) {
        return;
      }

      if (!mounted) return;
      if (existing.contains(chosen)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$chosen is already supported.')),
        );
        return;
      }

      final updatedSettings = settings.copyWith(
        supportedCurrencies: [...existing, chosen],
      );
      if (!mounted) return;
      await _persistCurrencySettings(
        context,
        store,
        updatedSettings,
        storeService,
        currencyProvider,
        successMessage: '$chosen added to supported currencies.',
      );
    } finally {
      manualController.dispose();
    }
  }

  Future<void> _removeCurrency(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    String currency,
    StoreService storeService,
    CurrencyProvider currencyProvider,
  ) async {
    final normalized = currency.toUpperCase();
    final base = settings.baseCurrency.toUpperCase();
    if (normalized == base) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot remove the base currency.')),
      );
      return;
    }
    final supported = settings.normalizedSupportedCurrencies
        .where((code) => code != normalized)
        .toList();
    var display = settings.effectiveDisplayCurrency;
    if (display == normalized) {
      display = base;
    }
    final updatedSettings = settings.copyWith(
      supportedCurrencies: supported,
      displayCurrency: display,
    );
    if (!mounted) return;
    await _persistCurrencySettings(
      context,
      store,
      updatedSettings,
      storeService,
      currencyProvider,
      successMessage: '$normalized removed from supported currencies.',
    );
  }

  Future<void> _showUpdateRateDialog(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    String currency,
    double? currentRate,
    CurrencyProvider currencyProvider,
  ) async {
    final controller = TextEditingController(
      text: currentRate != null ? currentRate.toStringAsFixed(4) : '',
    );
    if (!mounted) return;
    final result = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'Update ${settings.baseCurrency.toUpperCase()} → ${currency.toUpperCase()}',
          ),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(
              decimal: true,
              signed: false,
            ),
            decoration: const InputDecoration(
              labelText: 'Rate',
              helperText: 'Amount of quote currency for 1 base currency',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || parsed <= 0) {
                  Navigator.of(context).pop();
                  return;
                }
                Navigator.of(context).pop(parsed);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (result == null) {
      return;
    }

    setState(() {
      _isUpdatingCurrency = true;
    });
    try {
      await currencyProvider.upsertRate(
        FxRate(
          baseCurrency: settings.baseCurrency,
          quoteCurrency: currency,
          rate: result,
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Updated FX rate: 1 ${settings.baseCurrency.toUpperCase()} = '
            '${result.toStringAsFixed(4)} ${currency.toUpperCase()}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to update FX rate: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCurrency = false;
        });
      }
    }
  }

  Future<void> _refreshFxRates(
    BuildContext context,
    CurrencyProvider currencyProvider,
  ) async {
    setState(() {
      _isUpdatingCurrency = true;
    });
    try {
      await currencyProvider.refreshRates();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('FX rates refreshed.')));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to refresh FX rates: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCurrency = false;
        });
      }
    }
  }

  Future<void> _persistCurrencySettings(
    BuildContext context,
    Store store,
    CurrencySettings settings,
    StoreService storeService,
    CurrencyProvider currencyProvider, {
    String? successMessage,
  }) async {
    setState(() {
      _isUpdatingCurrency = true;
      _errorMessage = null;
    });
    final updatedStore = store.copyWith(currencySettings: settings);
    try {
      await storeService.saveStore(updatedStore);
      if (!mounted) return;
      await currencyProvider.applyStore(updatedStore);
      if (!mounted) return;
      if (successMessage != null && successMessage.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to update currency settings: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingCurrency = false;
        });
      }
    }
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

    if (!mounted) return;
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
      if (!mounted) return;
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
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a flag key.')));
      return;
    }

    final terminalId = _terminalIdController.text.trim();
    if (_selectedScope == FeatureFlagScope.terminal && terminalId.isEmpty) {
      if (!mounted) return;
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
