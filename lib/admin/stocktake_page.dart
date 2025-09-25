import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart';
import '../barcode_scanner_page.dart';
import '../services/stocktake_service.dart';
import '../stock_provider.dart';
import '../store_provider.dart';
class StocktakePage extends StatefulWidget {
  const StocktakePage({super.key});

  @override
  State<StocktakePage> createState() => _StocktakePageState();
}

class _StocktakePageState extends State<StocktakePage> {
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _expandedTiles = {};
  String? _error;
  bool _isProcessing = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stockProvider = context.watch<StockProvider>();
    final storeProvider = context.watch<StoreProvider>();
    final authService = context.watch<AuthService>();
    final stocktakeService = context.read<StocktakeService>();

    final ingredients = stockProvider.ingredients.values.where((ingredient) {
      final query = _searchController.text.trim().toLowerCase();
      if (query.isEmpty) return true;
      return ingredient.name.toLowerCase().contains(query) ||
          (ingredient.barcode?.contains(query) ?? false);
    }).toList()..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(title: const Text('Stocktake & Adjustments')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StoreSelector(
                  storeProvider: storeProvider,
                  authService: authService,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          labelText: 'Search ingredients',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: _searchController.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {});
                                  },
                                  icon: const Icon(Icons.clear),
                                ),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final scannedCode = await Navigator.of(context)
                            .push<String>(
                              MaterialPageRoute(
                                builder: (_) => const BarcodeScannerPage(),
                                fullscreenDialog: true,
                              ),
                            );
                        if (scannedCode != null) {
                          final ingredient = stockProvider.findByBarcode(
                            scannedCode,
                          );
                          if (ingredient != null) {
                            await _showStocktakeOptions(
                              context,
                              ingredient,
                              stocktakeService,
                              authService,
                              storeProvider,
                            );
                          } else {
                            setState(() {
                              _error =
                                  'No ingredient found for barcode $scannedCode';
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.qr_code_scanner),
                      label: const Text('Scan Barcode'),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: ingredients.isEmpty
                ? const Center(
                    child: Text('No ingredients found for the selected store.'),
                  )
                : ListView.builder(
                    itemCount: ingredients.length,
                    itemBuilder: (context, index) {
                      final ingredient = ingredients[index];
                      final isExpanded = _expandedTiles[ingredient.id] ?? false;
                      return Card(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: ExpansionTile(
                          key: ValueKey(ingredient.id),
                          title: Text(ingredient.name),
                          subtitle: Text(
                            'On hand: ${ingredient.stockQuantity.toStringAsFixed(2)} ${ingredient.unit}',
                          ),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged: (value) {
                            setState(() {
                              _expandedTiles[ingredient.id] = value;
                            });
                          },
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (ingredient.barcode != null)
                                    Text('Barcode: ${ingredient.barcode}'),
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 12,
                                    runSpacing: 12,
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed:
                                            authService.hasPermission(
                                              Permission.adjustInventory,
                                            )
                                            ? () => _handlePartialAdjustment(
                                                context,
                                                ingredient,
                                                stocktakeService,
                                                authService,
                                                storeProvider,
                                              )
                                            : null,
                                        icon: const Icon(Icons.tune),
                                        label: const Text('Partial Adjustment'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed:
                                            authService.hasPermission(
                                              Permission.adjustInventory,
                                            )
                                            ? () => _handleFullStocktake(
                                                context,
                                                ingredient,
                                                stocktakeService,
                                                authService,
                                                storeProvider,
                                              )
                                            : null,
                                        icon: const Icon(Icons.inventory),
                                        label: const Text('Record Stocktake'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          if (_isProcessing) const LinearProgressIndicator(minHeight: 2),
        ],
      ),
    );
  }

  Future<void> _handlePartialAdjustment(
    BuildContext context,
    Ingredient ingredient,
    StocktakeService stocktakeService,
    AuthService authService,
    StoreProvider storeProvider,
  ) async {
    final adjustmentController = TextEditingController();
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Partial Adjustment - ${ingredient.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: adjustmentController,
                decoration: const InputDecoration(
                  labelText: 'Adjustment amount',
                  helperText: 'Use negative numbers for shrinkage',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) return;

    final value = double.tryParse(adjustmentController.text);
    if (value == null) {
      setState(() {
        _error = 'Please enter a valid adjustment amount.';
      });
      return;
    }
    final tenantId = storeProvider.activeStore?.tenantId;
    if (tenantId == null) {
      setState(() {
        _error = 'Select a store before recording adjustments.';
      });
      return;
    }

    final targetStoreId =
        storeProvider.activeStore?.id ?? authService.activeStoreId;

    setState(() {
      _error = null;
      _isProcessing = true;
    });
    try {
      await stocktakeService.recordStockAdjustment(
        ingredient: ingredient,
        adjustment: value,
        actorId: authService.loggedInEmployee?.id ?? 'system',
        tenantId: tenantId,
        storeId: targetStoreId,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
    } catch (error) {
      setState(() {
        _error = 'Failed to record adjustment: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _handleFullStocktake(
    BuildContext context,
    Ingredient ingredient,
    StocktakeService stocktakeService,
    AuthService authService,
    StoreProvider storeProvider,
  ) async {
    final countedController = TextEditingController(
      text: ingredient.stockQuantity.toStringAsFixed(2),
    );
    final noteController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('Record Stocktake - ${ingredient.name}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: countedController,
                decoration: const InputDecoration(
                  labelText: 'Counted quantity',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              TextField(
                controller: noteController,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
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
    if (confirmed != true) return;

    final value = double.tryParse(countedController.text);
    if (value == null) {
      setState(() {
        _error = 'Please enter a valid quantity.';
      });
      return;
    }

    final tenantId = storeProvider.activeStore?.tenantId;
    if (tenantId == null) {
      setState(() {
        _error = 'Select a store before recording stocktakes.';
      });
      return;
    }

    final targetStoreId =
        storeProvider.activeStore?.id ?? authService.activeStoreId;
    setState(() {
      _error = null;
      _isProcessing = true;
    });
    try {
      await stocktakeService.recordFullStocktake(
        ingredient: ingredient,
        countedQuantity: value,
        actorId: authService.loggedInEmployee?.id ?? 'system',
        tenantId: tenantId,
        storeId: targetStoreId,
        note: noteController.text.trim().isEmpty
            ? null
            : noteController.text.trim(),
      );
    } catch (error) {
      setState(() {
        _error = 'Failed to record stocktake: $error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Future<void> _showStocktakeOptions(
    BuildContext context,
    Ingredient ingredient,
    StocktakeService stocktakeService,
    AuthService authService,
    StoreProvider storeProvider,
  ) async {
    final action = await showModalBottomSheet<_StocktakeAction>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.tune),
                title: const Text('Partial adjustment'),
                onTap: () =>
                    Navigator.of(context).pop(_StocktakeAction.partial),
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Record stocktake'),
                onTap: () =>
                    Navigator.of(context).pop(_StocktakeAction.stocktake),
              ),
            ],
          ),
        );
      },
    );

    if (action == _StocktakeAction.partial) {
      await _handlePartialAdjustment(
        context,
        ingredient,
        stocktakeService,
        authService,
        storeProvider,
      );
    } else if (action == _StocktakeAction.stocktake) {
      await _handleFullStocktake(
        context,
        ingredient,
        stocktakeService,
        authService,
        storeProvider,
      );
    }
  }
}

enum _StocktakeAction { partial, stocktake }

class _StoreSelector extends StatelessWidget {
  const _StoreSelector({
    required this.storeProvider,
    required this.authService,
  });

  final StoreProvider storeProvider;
  final AuthService authService;

  @override
  Widget build(BuildContext context) {
    final stores = storeProvider.stores;
    final selected = storeProvider.activeStore;

    if (storeProvider.isLoading) {
      return const LinearProgressIndicator(minHeight: 2);
    }

    if (stores.isEmpty) {
      return const Text('No stores available for your account.');
    }

    return Row(
      children: [
        const Text('Store:'),
        const SizedBox(width: 12),
        DropdownButton<Store>(
          value: selected,
          items: stores
              .map(
                (store) =>
                    DropdownMenuItem(value: store, child: Text(store.name)),
              )
              .toList(),
          onChanged: (value) {
            if (value == null) return;
            storeProvider.setActiveStore(value, authService);
            context.read<StockProvider>().setActiveStore(value.id);
          },
        ),
      ],
    );
  }
}
