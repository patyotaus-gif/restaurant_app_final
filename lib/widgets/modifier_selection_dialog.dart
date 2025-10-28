// lib/widgets/modifier_selection_dialog.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../admin/modifier_management_page.dart';

class ModifierSelectionDialog extends StatefulWidget {
  final Product product;

  const ModifierSelectionDialog({super.key, required this.product});

  @override
  State<ModifierSelectionDialog> createState() =>
      _ModifierSelectionDialogState();
}

class _ModifierSelectionDialogState extends State<ModifierSelectionDialog> {
  late Future<List<ModifierGroup>> _modifierGroupsFuture;
  final Map<String, dynamic> _selectedOptions = {};
  double _currentExtraPrice = 0.0;

  @override
  void initState() {
    super.initState();
    _modifierGroupsFuture = _fetchModifierGroups();
  }

  Future<List<ModifierGroup>> _fetchModifierGroups() async {
    if (widget.product.modifierGroupIds.isEmpty) {
      return [];
    }
    final snapshot = await FirebaseFirestore.instance
        .collection('modifierGroups')
        .where(FieldPath.documentId, whereIn: widget.product.modifierGroupIds)
        .get();
    return snapshot.docs
        .map((doc) => ModifierGroup.fromFirestore(doc))
        .toList();
  }

  void _updateSelection(String groupId, ModifierOption option, String type) {
    setState(() {
      if (type == 'SINGLE') {
        _selectedOptions[groupId] = option;
      } else if (type == 'MULTIPLE') {
        if (_selectedOptions[groupId] == null) {
          _selectedOptions[groupId] = <ModifierOption>[];
        }
        final currentSelections =
            _selectedOptions[groupId] as List<ModifierOption>;
        final existingOption = currentSelections.firstWhereOrNull(
          (o) => o.optionName == option.optionName,
        );

        if (existingOption != null) {
          currentSelections.remove(existingOption);
        } else {
          currentSelections.add(option);
        }
      }
      _recalculatePrice();
    });
  }

  void _recalculatePrice() {
    double extra = 0;
    _selectedOptions.forEach((groupId, selection) {
      if (selection is ModifierOption) {
        extra += selection.priceChange;
      } else if (selection is List<ModifierOption>) {
        for (var opt in selection) {
          extra += opt.priceChange;
        }
      }
    });
    _currentExtraPrice = extra;
  }

  // --- FIXED THIS FUNCTION ---
  void _confirmAndAddToCart(List<ModifierGroup> groups) {
    final List<Map<String, dynamic>> finalModifiers = [];

    _selectedOptions.forEach((groupId, selection) {
      // Find the groupName from the fully loaded list of groups
      final group = groups.firstWhere(
        (g) => g.id == groupId,
        orElse: () => ModifierGroup(groupName: 'Unknown'),
      );

      if (selection is ModifierOption) {
        finalModifiers.add({
          'groupName': group.groupName,
          'optionName': selection.optionName,
          'priceChange': selection.priceChange,
        });
      } else if (selection is List<ModifierOption>) {
        for (var opt in selection) {
          finalModifiers.add({
            'groupName': group.groupName,
            'optionName': opt.optionName,
            'priceChange': opt.priceChange,
          });
        }
      }
    });
    Navigator.of(context).pop(finalModifiers);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Options for ${widget.product.name}'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.4,
        child: FutureBuilder<List<ModifierGroup>>(
          future: _modifierGroupsFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError ||
                !snapshot.hasData ||
                snapshot.data!.isEmpty) {
              return const Center(child: Text('Could not load options.'));
            }

            final groups = snapshot.data!;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.6,
              ),
              child: Column(
                // Use column to separate list and total price
                mainAxisSize: MainAxisSize.max,
                children: [
                  Expanded(
                    // Make the list scrollable if it's too long
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: groups.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final group = groups[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.groupName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            if (group.selectionType == 'SINGLE')
                              ...group.options.map((option) {
                                return RadioListTile<ModifierOption>(
                                  title: Text(
                                    '${option.optionName} (+${option.priceChange.toStringAsFixed(2)})',
                                  ),
                                  value: option,
                                  groupValue: _selectedOptions[group.id!],
                                  onChanged: (value) => _updateSelection(
                                    group.id!,
                                    value!,
                                    'SINGLE',
                                  ),
                                );
                              }),
                            if (group.selectionType == 'MULTIPLE')
                              ...group.options.map((option) {
                                final currentList = List<ModifierOption>.from(
                                  _selectedOptions[group.id!]
                                          as List<ModifierOption>? ??
                                      [],
                                );
                                final isSelected = currentList.any(
                                  (o) => o.optionName == option.optionName,
                                );
                                return CheckboxListTile(
                                  title: Text(
                                    '${option.optionName} (+${option.priceChange.toStringAsFixed(2)})',
                                  ),
                                  value: isSelected,
                                  onChanged: (value) => _updateSelection(
                                    group.id!,
                                    option,
                                    'MULTIPLE',
                                  ),
                                );
                              }),
                          ],
                        );
                      },
                    ),
                  ),
                  const Divider(),
                  Padding(
                    // Total price at the bottom
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'Total Price: ${(widget.product.price + _currentExtraPrice).toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        // Pass the loaded groups to the confirm function
        FutureBuilder<List<ModifierGroup>>(
          future: _modifierGroupsFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const ElevatedButton(
                onPressed: null,
                child: Text('Add to Cart'),
              );
            }
            return ElevatedButton(
              onPressed: () => _confirmAndAddToCart(snapshot.data!),
              child: const Text('Add to Cart'),
            );
          },
        ),
      ],
    );
  }
}
