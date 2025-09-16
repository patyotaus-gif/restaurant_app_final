// lib/edit_product_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:go_router/go_router.dart';
import 'models/product_model.dart';
import 'barcode_scanner_page.dart';
import 'admin/modifier_management_page.dart';

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

  List<ModifierGroup> _availableModifierGroups = [];
  List<String> _selectedModifierGroupIds = [];
  bool _isLoadingModifiers = true;

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

    if (p != null) {
      _selectedModifierGroupIds = List<String>.from(p.modifierGroupIds);
    }
    _fetchModifierGroups();
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

  @override
  void dispose() {
    _nameController.dispose();
    _priceController.dispose();
    _descriptionController.dispose();
    _imageUrlController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
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
        recipe: widget.product?.recipe ?? [],
        variations: widget.product?.variations ?? [],
        modifierGroupIds: _selectedModifierGroupIds,
      ).toFirestore();

      try {
        final collection = FirebaseFirestore.instance.collection('menu_items');
        if (widget.product == null) {
          await collection.add(productData);
        } else {
          await collection.doc(widget.product!.id).update(productData);
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
                value: _selectedCategory,
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
              _buildSectionHeader('Inventory & Type'),
              DropdownButtonFormField<ProductType>(
                value: _productType,
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
                _buildSectionHeader('Recipe (for Food items)'),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Center(
                    child: Text('Recipe management UI will be here.'),
                  ),
                ),
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
}
