// lib/customer_menu_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'cart_provider.dart';
import 'customer_checkout_page.dart';
import 'services/menu_cache_provider.dart';
class CustomerMenuPage extends StatefulWidget {
  final String tableNumber;

  const CustomerMenuPage({super.key, required this.tableNumber});

  @override
  State<CustomerMenuPage> createState() => _CustomerMenuPageState();
}

class _CustomerMenuPageState extends State<CustomerMenuPage> {
  final Map<String, CartItem> _tempCart = {};
  final Map<String, String> _categories = {
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
  late String _selectedCategory;

  final _promoCodeController = TextEditingController();
  Promotion? _appliedPromotion;
  double _promoDiscount = 0.0;

  @override
  void initState() {
    super.initState();
    _selectedCategory = _categories.keys.first;
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  double get _subtotal => _tempCart.values.fold(
    0.0,
    (total, item) => total + (item.price * item.quantity),
  );

  double get _cartTotal {
    final total = _subtotal - _promoDiscount;
    return total < 0 ? 0 : total;
  }

  // --- 2. Update method to accept a Product ---
  void _addItemToCart(Product product) {
    setState(() {
      if (_tempCart.containsKey(product.id)) {
        _tempCart.update(product.id, (existingItem) {
          existingItem.quantity++;
          return existingItem;
        });
      } else {
        // --- 3. Update CartItem constructor ---
        _tempCart[product.id] = CartItem(product: product);
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${product.name} added to cart.'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _incrementCartItem(String productId) {
    setState(() {
      _tempCart[productId]!.quantity++;
    });
  }

  void _decrementCartItem(String productId) {
    setState(() {
      if (_tempCart.containsKey(productId)) {
        if (_tempCart[productId]!.quantity > 1) {
          _tempCart[productId]!.quantity--;
        } else {
          _tempCart.remove(productId);
        }
      }
    });
  }

  Future<void> _applyPromotionCode(StateSetter setModalState) async {
    final code = _promoCodeController.text;
    if (code.isEmpty) return;

    final codeUpperCase = code.toUpperCase();
    final promoQuery = await FirebaseFirestore.instance
        .collection('promotions')
        .where('code', isEqualTo: codeUpperCase)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (promoQuery.docs.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Invalid or inactive code.")),
        );
      }
      return;
    }

    final promo = Promotion.fromFirestore(promoQuery.docs.first);
    final categories = _tempCart.values.map((item) => item.category).toSet();
    final totalItems = _tempCart.values.fold<int>(
      0,
      (count, item) => count + item.quantity,
    );
    final validationMessage = promo.rules.validate(
      subtotal: _subtotal,
      itemCount: totalItems,
      categories: categories,
      orderType: 'dineIn',
      currentTime: DateTime.now(),
    );

    if (validationMessage != null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(validationMessage)));
      }
      return;
    }

    double calculatedDiscount = 0;

    if (promo.type == 'percentage') {
      calculatedDiscount = _subtotal * (promo.value / 100);
    } else {
      calculatedDiscount = promo.value;
    }

    setModalState(() {
      _appliedPromotion = promo;
      _promoDiscount = (_subtotal < calculatedDiscount)
          ? _subtotal
          : calculatedDiscount;
    });
    setState(() {});
  }

  void _removePromotion(StateSetter setModalState) {
    setModalState(() {
      _appliedPromotion = null;
      _promoDiscount = 0.0;
    });
    setState(() {});
  }

  void _showCartBottomSheet() {
    _promoCodeController.clear();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            void updateModalState(Function action) {
              setModalState(() => action());
              setState(() {});
            }

            if (_tempCart.isEmpty) {
              if (_appliedPromotion != null) _removePromotion(setModalState);
              return const SizedBox(
                height: 200,
                child: Center(child: Text('Your cart is empty.')),
              );
            }
            return Padding(
              padding: const EdgeInsets.all(8.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: Text(
                        'Your Order for Table ${widget.tableNumber}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _tempCart.length,
                        itemBuilder: (context, index) {
                          final item = _tempCart.values.toList()[index];
                          return ListTile(
                            title: Text(item.name),
                            subtitle: Text(
                              '${item.price.toStringAsFixed(2)} Baht',
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove),
                                  onPressed: () => updateModalState(
                                    () => _decrementCartItem(item.id),
                                  ),
                                ),
                                Text(
                                  item.quantity.toString(),
                                  style: const TextStyle(fontSize: 16),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.add),
                                  onPressed: () => updateModalState(
                                    () => _incrementCartItem(item.id),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Subtotal:'),
                              Text('${_subtotal.toStringAsFixed(2)} Baht'),
                            ],
                          ),
                          if (_appliedPromotion != null)
                            ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(
                                "Promo: ${_appliedPromotion!.code}",
                                style: TextStyle(color: Colors.green.shade800),
                              ),
                              subtitle: Text(_appliedPromotion!.description),
                              trailing: Text(
                                "-${_promoDiscount.toStringAsFixed(2)} Baht",
                                style: TextStyle(color: Colors.green.shade800),
                              ),
                              leading: IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    _removePromotion(setModalState),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _promoCodeController,
                                      decoration: const InputDecoration(
                                        labelText: "Promo Code",
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: () =>
                                        _applyPromotionCode(setModalState),
                                    child: const Text("Apply"),
                                  ),
                                ],
                              ),
                            ),
                          const Divider(),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total:',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '${_cartTotal.toStringAsFixed(2)} Baht',
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerCheckoutPage(
                                      tableNumber: widget.tableNumber,
                                      cart: _tempCart,
                                      totalAmount: _cartTotal,
                                      appliedPromotion: _appliedPromotion,
                                      discountAmount: _promoDiscount,
                                    ),
                                  ),
                                );
                              },
                              child: const Text(
                                'Proceed to Checkout',
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    ).whenComplete(() => setState(() {}));
  }

  void _showItemDetailsDialog(BuildContext context, Product product) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          contentPadding: EdgeInsets.zero,
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 200,
                  child: product.imageUrl.isNotEmpty
                      ? Image.network(
                          product.imageUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.broken_image,
                                size: 50,
                                color: Colors.grey,
                              ),
                        )
                      : Container(
                          color: Colors.grey.shade200,
                          child: const Icon(
                            Icons.image_not_supported,
                            size: 50,
                            color: Colors.grey,
                          ),
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${product.price.toStringAsFixed(2)} Baht',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        product.description.isNotEmpty
                            ? product.description
                            : 'No description available.',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu for Table ${widget.tableNumber}'),
        backgroundColor: Colors.deepOrange,
        actions: [
          IconButton(
            icon: const Icon(Icons.shopping_cart),
            onPressed: _showCartBottomSheet,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Wrap(
              spacing: 8.0,
              runSpacing: 4.0,
              children: _categories.entries.map((entry) {
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: _selectedCategory == entry.key,
                  onSelected: (selected) {
                    if (selected) setState(() => _selectedCategory = entry.key);
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
                  return const Center(
                    child: Text('No items in this category.'),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final product = items[index];
                    return _buildProductCard(product);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductCard(Product product) {
    const isAvailable = true; // Simplified for customer menu

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _showItemDetailsDialog(context, product),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 100,
              height: 100,
              child: product.imageUrl.isNotEmpty
                  ? Ink.image(
                      image: NetworkImage(product.imageUrl),
                      fit: BoxFit.cover,
                    )
                  : Container(
                      color: Colors.grey.shade200,
                      child: Icon(
                        Icons.fastfood_outlined,
                        color: Colors.grey.shade400,
                        size: 40,
                      ),
                    ),
            ),
            Expanded(
              child: SizedBox(
                height: 100,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (product.description.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            product.description,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      const Spacer(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${product.price.toStringAsFixed(2)} Baht',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.deepOrange,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.add_shopping_cart,
                              color: Colors.green,
                            ),
                            onPressed: isAvailable
                                ? () => _addItemToCart(product)
                                : null,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
