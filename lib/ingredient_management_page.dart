// lib/ingredient_management_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'add_purchase_order_page.dart'; // <-- 1. Add this import
import 'currency_provider.dart';
import 'locale_provider.dart';
import 'localization/localization_extensions.dart';
class IngredientManagementPage extends StatefulWidget {
  const IngredientManagementPage({super.key});

  @override
  State<IngredientManagementPage> createState() =>
      _IngredientManagementPageState();
}

class _IngredientManagementPageState extends State<IngredientManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late final CollectionReference<Ingredient> _ingredientsRef;

  @override
  void initState() {
    super.initState();
    _ingredientsRef = _firestore
        .collection('ingredients')
        .withConverter<Ingredient>(
          fromFirestore: Ingredient.fromFirestore,
          toFirestore: (ingredient, _) => ingredient.toFirestore(),
        );
  }

  void _showIngredientDialog({Ingredient? ingredient}) {
    final isNew = ingredient == null;
    final l10n = AppLocalizations.of(context)!;
    final nameController = TextEditingController(text: ingredient?.name);
    final unitController = TextEditingController(text: ingredient?.unit);
    final stockController = TextEditingController(
      text: ingredient?.stockQuantity.toString(),
    );
    final thresholdController = TextEditingController(
      text: ingredient?.lowStockThreshold.toString(),
    );
    final costController = TextEditingController(
      text: ingredient?.cost.toString(),
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            isNew
                ? l10n.ingredientDialogCreateTitle
                : l10n.ingredientDialogEditTitle,
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: l10n.ingredientFieldNameLabel,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true)
                            ? l10n.ingredientFieldNameValidation
                            : null,
                  ),
                  TextFormField(
                    controller: unitController,
                    decoration: InputDecoration(
                      labelText: l10n.ingredientFieldUnitLabel,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true)
                            ? l10n.ingredientFieldUnitValidation
                            : null,
                  ),
                  TextFormField(
                    controller: stockController,
                    decoration: InputDecoration(
                      labelText: l10n.ingredientFieldStockLabel,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true)
                            ? l10n.ingredientFieldStockValidation
                            : null,
                  ),
                  TextFormField(
                    controller: costController,
                    decoration: InputDecoration(
                      labelText: l10n.ingredientFieldCostLabel,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        (value?.isEmpty ?? true)
                            ? l10n.ingredientFieldCostValidation
                            : null,
                  ),
                  TextFormField(
                    controller: thresholdController,
                    decoration: InputDecoration(
                      labelText: l10n.ingredientFieldThresholdLabel,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) => (value?.isEmpty ?? true)
                        ? l10n.ingredientFieldThresholdValidation
                        : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final dataToSave = Ingredient(
                    id: ingredient?.id ?? '',
                    name: nameController.text,
                    unit: unitController.text,
                    stockQuantity: double.tryParse(stockController.text) ?? 0.0,
                    lowStockThreshold:
                        double.tryParse(thresholdController.text) ?? 0.0,
                    cost: double.tryParse(costController.text) ?? 0.0,
                  );

                  if (isNew) {
                    _ingredientsRef.add(dataToSave);
                  } else {
                    _ingredientsRef
                        .doc(ingredient.id)
                        .update(dataToSave.toFirestore());
                  }
                  Navigator.of(context).pop();
                }
              },
              child: Text(l10n.commonSave),
            ),
          ],
        );
      },
    );
  }

  void _deleteIngredient(String docId) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.ingredientDeleteTitle),
          content: Text(l10n.ingredientDeleteMessage),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(l10n.commonCancel),
            ),
            ElevatedButton(
              onPressed: () {
                _ingredientsRef.doc(docId).delete();
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: Text(l10n.commonDelete),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currencyProvider = context.watch<CurrencyProvider>();
    final localeProvider = context.watch<LocaleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.ingredientPageTitle),
        // --- 2. Add this actions section ---
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add_check_circle_outlined),
            tooltip: l10n.ingredientAddPurchaseOrderTooltip,
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => const AddPurchaseOrderPage(),
                ),
              );
            },
          ),
        ],
        // ---------------------------------
      ),
      body: StreamBuilder<QuerySnapshot<Ingredient>>(
        stream: _ingredientsRef.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                l10n.ingredientListError('${snapshot.error}'),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text(l10n.ingredientListEmpty));
          }

          final ingredients = snapshot.data!.docs;

          return ListView.builder(
            itemCount: ingredients.length,
            itemBuilder: (context, index) {
              final ingredientDoc = ingredients[index];
              final ingredient = ingredientDoc.data();
              final isLowStock =
                  ingredient.stockQuantity <= ingredient.lowStockThreshold;
              final quantityDigits =
                  ingredient.stockQuantity % 1 == 0 ? 0 : 2;
              final quantityDisplay = localeProvider.formatNumber(
                ingredient.stockQuantity,
                decimalDigits: quantityDigits,
              );
              final unitLabel = l10n.localizedUnitLabel(ingredient.unit);
              final avgCostDisplay = currencyProvider.format(ingredient.cost);
              final subtitleText =
                  l10n.ingredientSummary(quantityDisplay, unitLabel, avgCostDisplay);

              return Card(
                color: isLowStock ? Colors.red.withAlpha(25) : null,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(ingredient.name),
                  subtitle: Text(subtitleText),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () =>
                            _showIngredientDialog(ingredient: ingredient),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteIngredient(ingredientDoc.id),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showIngredientDialog(),
        tooltip: l10n.ingredientFabTooltip,
        child: const Icon(Icons.add),
      ),
    );
  }
}
