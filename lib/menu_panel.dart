// lib/menu_panel.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'cart_provider.dart';
import 'localization/app_localizations.dart';
import 'services/menu_cache_provider.dart';
import 'stock_provider.dart';
class MenuPanel extends StatefulWidget {
  const MenuPanel({super.key});

  @override
  State<MenuPanel> createState() => _MenuPanelState();
}

class _MenuPanelState extends State<MenuPanel> {
  static const List<String> _categoryKeys = [
    'soft_drinks',
    'beers',
    'hot_drinks',
    'munchies',
    'the_fish',
    'noodle_dishes',
    'rice_dishes',
    'noodle_soups',
    'the_salad',
    'dessert',
  ];

  late String _selectedCategory;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categoryKeys.first;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    if (localizations == null) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Wrap(
            spacing: 8.0,
            runSpacing: 4.0,
            children: _categoryKeys.map((categoryKey) {
              final label = _categoryLabel(localizations, categoryKey);
              return ChoiceChip(
                label: Text(label),
                labelStyle: const TextStyle(fontSize: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 8.0,
                  vertical: 4.0,
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                selected: _selectedCategory == categoryKey,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedCategory = categoryKey;
                    });
                  }
                },
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: Consumer<MenuCacheProvider>(
            builder: (context, menuCache, child) {
              final items = menuCache
                  .productsByCategory(_selectedCategory)
                  .toList();
              if (!menuCache.isReady) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return Center(
                  child: Text(
                    localizations.menuCategoryEmpty(
                      _categoryLabel(localizations, _selectedCategory),
                    ),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(12.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 4 / 3,
                ),
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final product = items[index];

                  return Consumer2<CartProvider, StockProvider>(
                    builder: (context, cart, stock, child) {
                      final int quantityInCart =
                          cart.items[product.id]?.quantity ?? 0;
                      final bool isAvailable = stock.isProductAvailable(
                        product,
                        quantityToCheck: quantityInCart + 1,
                      );

                      return ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.black87,
                          backgroundColor: isAvailable
                              ? Colors.white
                              : Colors.grey.shade300,
                          shadowColor: Colors.grey.shade300,
                          elevation: 3,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.all(8),
                        ),
                        onPressed: isAvailable
                            ? () {
                                final success = cart.addItem(product);
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('สินค้าในสต็อกไม่เพียงพอ!'),
                                      backgroundColor: Colors.red,
                                      duration: Duration(seconds: 2),
                                    ),
                                  );
                                }
                              }
                            : null,
                        child: Stack(
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      product.name,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                                Text(
                                  '${product.price} บาท',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            if (!isAvailable)
                              Container(
                                alignment: Alignment.center,
                                color: Colors.black.withOpacity(0.5),
                                child: const Text(
                                  'สินค้าหมด',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  String _categoryLabel(
    AppLocalizations localizations,
    String categoryKey,
  ) {
    switch (categoryKey) {
      case 'soft_drinks':
        return localizations.menuCategorySoftDrinks;
      case 'beers':
        return localizations.menuCategoryBeers;
      case 'hot_drinks':
        return localizations.menuCategoryHotDrinks;
      case 'munchies':
        return localizations.menuCategoryMunchies;
      case 'the_fish':
        return localizations.menuCategoryTheFish;
      case 'noodle_dishes':
        return localizations.menuCategoryNoodleDishes;
      case 'rice_dishes':
        return localizations.menuCategoryRiceDishes;
      case 'noodle_soups':
        return localizations.menuCategoryNoodleSoups;
      case 'the_salad':
        return localizations.menuCategoryTheSalad;
      case 'dessert':
        return localizations.menuCategoryDessert;
      default:
        return categoryKey;
    }
  }
}
