// lib/edit_product_page.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'admin/modifier_management_page.dart';
import 'barcode_scanner_page.dart';

import 'services/firestore_converters.dart';

class EditProductPage extends StatefulWidget {
  final Product? product;

  const EditProductPage({super.key, this.product});

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _priceController;
  late TextEditingController _descriptionController;
  late TextEditingController _imageUrlController;
  String? _selectedCategory;
  late ProductType _productType;
  late bool _trackStock;
  late TextEditingController _skuController;
  late TextEditingController _barcodeController;
  late TextEditingController _costPriceController;
  late TextEditingController _kitchenStationsController;
  late TextEditingController _prepTimeController;

  List<ModifierGroup> _availableModifierGroups = [];
  List<String> _selectedModifierGroupIds = [];
  bool _isLoadingModifiers = true;
  List<Ingredient> _availableIngredients = [];
  bool _isLoadingIngredients = true;
  List<Map<String, dynamic>> _recipeData = [];

  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  String? _imageFilePath;

  @override
  void initState() {
    super.initState();
    final p = widget.product;

    _nameController = TextEditingController(text: p?.name ?? '');
    _priceController = TextEditingController(text: p?.price.toString() ?? '');
    _descriptionController = TextEditingController(text: p?.description ?? '');
    _imageUrlController = TextEditingController(text: p?.imageUrl ?? '');
    _selectedCategory = p?.category;

    _productType = p?.productType ?? ProductType.general;
    _trackStock = p?.trackStock ?? true;
    _skuController = TextEditingController(text: p?.sku ?? '');
    _barcodeController = TextEditingController(text: p?.barcode ?? '');
    _costPriceController = TextEditingController(
      text: p?.costPrice.toString() ?? '0.0',
    );
    _kitchenStationsController = TextEditingController(
      text: (p?.kitchenStations ?? const []).join(', '),
    );
    _prepTimeController = TextEditingController(
      text: (p?.prepTimeMinutes ?? 0).toString(),
    );
    _recipeData =
        p?.recipe.map((item) => Map<String, dynamic>.from(item)).toList() ?? [];

    if (p != null) {
      _selectedModifierGroupIds = List<String>.from(p.modifierGroupIds);
    }
    _fetchModifierGroups();
    _loadIngredients();
  }

  Future<void> _fetchModifierGroups() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('modifierGroups')
          .orderBy('groupName')
          .get();
      final groups = snapshot.docs
          .map((doc) => ModifierGroup.fromFirestore(doc))
          .toList();
      setState(() {
        _availableModifierGroups = groups;
        _isLoadingModifiers = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingModifiers = false;
      });
    }
  }

  Future<void> _loadIngredients() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('ingredients')
          .orderBy('name')
          .get();
      final ingredients = snapshot.docs
          .map((doc) => Ingredient.fromSnapshot(doc))
          .toList();
      if (!mounted) return;
      setState(() {
        _availableIngredients = ingredients;
        _isLoadingIngredients = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingIngredients = false;
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _kitchenStationsController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  Future<void> _scanBarcode() async {
    // This function will now be used by the barcode button
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        _barcodeController.text = result;
      });
    }
  }

  Future<void> _pickAndUploadImage() async {
    // This function will now be used by the image picker button
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    setState(() {
      _isUploading = true;
      _imageFilePath = image.path;
    });

    try {
      final file = File(image.path);
      final fileName =
          'product_images/${DateTime.now().millisecondsSinceEpoch}_${image.name}';
      final ref = FirebaseStorage.instance.ref().child(fileName);
      final snapshot = await ref.putFile(file);
      final downloadUrl = await snapshot.ref.getDownloadURL();

      setState(() {
        _imageUrlController.text = downloadUrl;
        _isUploading = false;
      });
    } catch (e) {
      setState(() {
        _isUploading = false;
        _imageFilePath = null;
      });
    }
  }

  Future<void> _saveProduct() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();

      final productData = Product(
        id: widget.product?.id ?? '',
        name: _nameController.text,
        price: double.tryParse(_priceController.text) ?? 0.0,
        category: _selectedCategory ?? 'uncategorized',
        description: _descriptionController.text,
        imageUrl: _imageUrlController.text,
        productType: _productType,
        trackStock: _trackStock,
        sku: _skuController.text,
        barcode: _barcodeController.text,
        costPrice: double.tryParse(_costPriceController.text) ?? 0.0,
        recipe: _recipeData,
        variations: widget.product?.variations ?? [],
        modifierGroupIds: _selectedModifierGroupIds,
        kitchenStations: _kitchenStationsController.text
            .split(',')
            .map((station) => station.trim())
            .where((station) => station.isNotEmpty)
            .toList(),
        prepTimeMinutes: double.tryParse(_prepTimeController.text) ?? 0.0,
      );

      try {
        final collection = FirebaseFirestore.instance.menuItemsRef;
        if (widget.product == null) {
          await collection.add(productData);
        } else {
          await collection
              .doc(widget.product!.id)
              .set(productData, SetOptions(merge: true));
        }
        if (mounted) {
          context.pop();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error saving product: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.product == null ? 'Add New Product' : 'Edit Product',
        ),
        actions: [
          IconButton(icon: const Icon(Icons.save), onPressed: _saveProduct),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildSectionHeader('General Information'),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Product Name',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'soft_drinks',
                    child: Text('SOFT DRINKS'),
                  ),
                  DropdownMenuItem(value: 'beers', child: Text('BEERS')),
                  DropdownMenuItem(
                    value: 'hot_drinks',
                    child: Text('Hot Drinks'),
                  ),
                  DropdownMenuItem(value: 'munchies', child: Text('Munchies')),
                  DropdownMenuItem(value: 'the_fish', child: Text('The Fish')),
                  DropdownMenuItem(
                    value: 'noodle_dishes',
                    child: Text('Noodle Dishes'),
                  ),
                  DropdownMenuItem(
                    value: 'rice_dishes',
                    child: Text('Rice Dishes'),
                  ),
                  DropdownMenuItem(
                    value: 'noodle_soups',
                    child: Text('Noodle Soups'),
                  ),
                  DropdownMenuItem(
                    value: 'the_salad',
                    child: Text('The Salad'),
                  ),
                  DropdownMenuItem(value: 'dessert', child: Text('Dessert')),
                  DropdownMenuItem(
                    value: 'retail_general',
                    child: Text('Retail - General'),
                  ),
                ],
                onChanged: (value) => setState(() => _selectedCategory = value),
                validator: (v) => v == null ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Pricing'),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costPriceController,
                      decoration: const InputDecoration(
                        labelText: 'Cost Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => (double.tryParse(v ?? '') == null)
                          ? 'Invalid number'
                          : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _priceController,
                      decoration: const InputDecoration(
                        labelText: 'Selling Price',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      validator: (v) => (double.tryParse(v ?? '') == null)
                          ? 'Invalid number'
                          : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Kitchen Routing'),
              TextFormField(
                controller: _kitchenStationsController,
                decoration: const InputDecoration(
                  labelText: 'Kitchen Stations',
                  helperText: 'Comma separated station IDs (e.g. grill,bar)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _prepTimeController,
                decoration: const InputDecoration(
                  labelText: 'Prep Time SLA (minutes)',
                  border: OutlineInputBorder(),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
              const SizedBox(height: 24),
              _buildSectionHeader('Inventory & Type'),
              DropdownButtonFormField<ProductType>(
                initialValue: _productType,
                decoration: const InputDecoration(
                  labelText: 'Product Type',
                  border: OutlineInputBorder(),
                ),
                items: ProductType.values
                    .map(
                      (type) => DropdownMenuItem(
                        value: type,
                        child: Text(type.name.toUpperCase()),
                      ),
                    )
                    .toList(),
                onChanged: (value) =>
                    setState(() => _productType = value ?? ProductType.general),
              ),
              if (_productType != ProductType.service) ...[
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Track Stock'),
                  value: _trackStock,
                  onChanged: (value) => setState(() => _trackStock = value),
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _skuController,
                  decoration: const InputDecoration(
                    labelText: 'SKU',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _barcodeController,
                  decoration: InputDecoration(
                    labelText: 'Barcode (UPC, EAN)',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: _scanBarcode, // Reconnected this button
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),
              _buildSectionHeader('Modifiers & Combos'),
              _isLoadingModifiers
                  ? const Center(child: CircularProgressIndicator())
                  : _availableModifierGroups.isEmpty
                  ? const Center(
                      child: Text(
                        'No modifier groups found. Create them first.',
                      ),
                    )
                  : Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Column(
                        children: _availableModifierGroups.map((group) {
                          return CheckboxListTile(
                            title: Text(group.groupName),
                            subtitle: Text(group.selectionType),
                            value: _selectedModifierGroupIds.contains(group.id),
                            onChanged: (bool? value) {
                              setState(() {
                                if (value == true) {
                                  _selectedModifierGroupIds.add(group.id!);
                                } else {
                                  _selectedModifierGroupIds.remove(group.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      ),
                    ),
              if (_productType == ProductType.food) ...[
                const SizedBox(height: 24),
                _buildSectionHeader('Bill of Materials (Ingredients)'),
                _buildRecipeManagementCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildRecipeManagementCard() {
    if (_isLoadingIngredients) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recipeData.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text(
                'No ingredients added yet. Use the button below to build the recipe.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            Column(
              children: _recipeData.asMap().entries.map((entry) {
                final index = entry.key;
                final data = entry.value;
                final ingredientName = (data['ingredientName'] as String?)
                    ?.trim();
                final unit = (data['unit'] as String?)?.trim();
                final quantity = (data['quantity'] as num?)?.toDouble() ?? 0.0;
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    title: Text(
                      ingredientName?.isEmpty ?? true
                          ? 'Unknown Ingredient'
                          : ingredientName!,
                    ),
                    subtitle: Text(
                      unit == null || unit.isEmpty
                          ? 'Quantity: ${quantity.toStringAsFixed(2)}'
                          : 'Quantity: ${quantity.toStringAsFixed(2)} $unit',
                    ),
                    trailing: Wrap(
                      spacing: 8,
                      children: [
                        IconButton(
                          tooltip: 'Edit quantity',
                          icon: const Icon(Icons.edit),
                          onPressed: () => _editRecipeItemQuantity(index),
                        ),
                        IconButton(
                          tooltip: 'Remove ingredient',
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _removeRecipeItem(index),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Add Ingredient'),
              onPressed: _availableIngredients.isEmpty
                  ? null
                  : _showAddRecipeItemDialog,
            ),
          ),
        ],
      ),
    );
  }

  void _showAddRecipeItemDialog() {
    if (_availableIngredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No ingredients available. Please add ingredients.'),
        ),
      );
      return;
    }

    String? selectedIngredientId = _availableIngredients.first.id;
    final quantityController = TextEditingController(text: '1');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Ingredient'),
          content: StatefulBuilder(
            builder: (context, setStateDialog) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: selectedIngredientId,
                    decoration: const InputDecoration(labelText: 'Ingredient'),
                    items: _availableIngredients
                        .map(
                          (ingredient) => DropdownMenuItem(
                            value: ingredient.id,
                            child: Text(ingredient.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setStateDialog(() => selectedIngredientId = value),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: quantityController,
                    decoration: const InputDecoration(
                      labelText: 'Quantity per serving',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity =
                    double.tryParse(quantityController.text.trim()) ?? 0.0;
                if (selectedIngredientId == null || quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select ingredient and quantity.'),
                    ),
                  );
                  return;
                }

                final ingredient = _availableIngredients.firstWhere(
                  (ing) => ing.id == selectedIngredientId,
                );

                setState(() {
                  _recipeData.add({
                    'ingredientId': ingredient.id,
                    'ingredientName': ingredient.name,
                    'unit': ingredient.unit,
                    'quantity': quantity,
                  });
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _editRecipeItemQuantity(int index) {
    final data = _recipeData[index];
    final controller = TextEditingController(
      text: ((data['quantity'] as num?)?.toDouble() ?? 0.0).toString(),
    );

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Quantity'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantity per serving',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final quantity = double.tryParse(controller.text.trim()) ?? 0.0;
                if (quantity <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid quantity.')),
                  );
                  return;
                }
                setState(() {
                  _recipeData[index]['quantity'] = quantity;
                });
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _removeRecipeItem(int index) {
    setState(() {
      _recipeData.removeAt(index);
    });
  }
}
