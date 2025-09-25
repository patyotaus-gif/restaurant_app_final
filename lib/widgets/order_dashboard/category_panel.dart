// lib/widgets/order_dashboard/category_panel.dart

import 'package:flutter/material.dart';
class CategoryPanel extends StatelessWidget {
  // Map of category keys and their display names
  final Map<String, String> categories = const {
    'soft_drinks': 'SOFT DRINKS',
    'beers': 'BEERS',
    'hot_drinks': 'Hot Drinks',
    'munchies': 'Munchies',
    'the_fish': 'The Fish',
    'noodle_dishes': 'Noodle Dishes',
    'rice_dishes': 'Rice Dishes',
    'noodle_soups': 'Noodle Soups',
    'the_salad': 'The Salad',
    'dessert': 'Dessert',
  };

  final String selectedCategory;
  final Function(String) onCategorySelected;

  const CategoryPanel({
    super.key,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
        backgroundColor: Theme.of(context).colorScheme.surface,
        elevation: 1,
        automaticallyImplyLeading: false, // No back button
      ),
      body: ListView.separated(
        itemCount: categories.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final categoryKey = categories.keys.elementAt(index);
          final categoryName = categories.values.elementAt(index);
          final bool isSelected = selectedCategory == categoryKey;

          return ListTile(
            title: Text(categoryName),
            selected: isSelected,
            selectedTileColor: Theme.of(
              context,
            ).colorScheme.primary.withOpacity(0.1),
            onTap: () => onCategorySelected(categoryKey),
          );
        },
      ),
    );
  }
}
