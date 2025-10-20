// lib/admin/modifier_management_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../widgets/form_field_row.dart';

// --- Data Models (Helper classes for this page) ---
class ModifierOption {
  String optionName;
  double priceChange;

  ModifierOption({this.optionName = '', this.priceChange = 0.0});

  Map<String, dynamic> toMap() {
    return {'optionName': optionName, 'priceChange': priceChange};
  }

  static ModifierOption fromMap(Map<String, dynamic> map) {
    return ModifierOption(
      optionName: map['optionName'] ?? '',
      priceChange: (map['priceChange'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ModifierGroup {
  final String? id;
  String groupName;
  String selectionType;
  List<ModifierOption> options;

  ModifierGroup({
    this.id,
    this.groupName = '',
    this.selectionType = 'SINGLE',
    List<ModifierOption>? options,
  }) : options = options ?? [ModifierOption()];

  Map<String, dynamic> toFirestore() {
    return {
      'groupName': groupName,
      'selectionType': selectionType,
      'options': options.map((opt) => opt.toMap()).toList(),
    };
  }

  static ModifierGroup fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ModifierGroup(
      id: doc.id,
      groupName: data['groupName'] ?? '',
      selectionType: data['selectionType'] ?? 'SINGLE',
      options:
          (data['options'] as List<dynamic>?)
              ?.map((opt) => ModifierOption.fromMap(opt))
              .toList() ??
          [],
    );
  }
}
// ----------------------------------------------------

class ModifierManagementPage extends StatefulWidget {
  const ModifierManagementPage({super.key});

  @override
  State<ModifierManagementPage> createState() => _ModifierManagementPageState();
}

class _ModifierManagementPageState extends State<ModifierManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- FIX: Added 'async' to the function signature ---
  Future<void> _showModifierGroupDialog({ModifierGroup? existingGroup}) async {
    final ModifierGroup? initialGroup = existingGroup;
    final bool isNew = initialGroup == null;

    late ModifierGroup group;
    if (initialGroup == null) {
      group = ModifierGroup();
    } else {
      final snapshot = await _firestore
          .collection('modifierGroups')
          .doc(initialGroup.id)
          .get();
      group = ModifierGroup.fromFirestore(snapshot);
    }

    if (!mounted) return;

    final groupNameController = TextEditingController(text: group.groupName);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (stfContext, stfSetState) {
            return AlertDialog(
              title: Text(isNew ? 'Add Modifier Group' : 'Edit Modifier Group'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: groupNameController,
                      decoration: const InputDecoration(
                        labelText: 'Group Name (e.g., Size, Doneness)',
                      ),
                      onChanged: (value) => group.groupName = value,
                    ),
                    DropdownButtonFormField<String>(
                      initialValue: group.selectionType,
                      decoration: const InputDecoration(
                        labelText: 'Selection Type',
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: 'SINGLE',
                          child: Text('Single Choice (Radio Button)'),
                        ),
                        DropdownMenuItem(
                          value: 'MULTIPLE',
                          child: Text('Multiple Choice (Checkbox)'),
                        ),
                      ],
                      onChanged: (value) {
                        stfSetState(() => group.selectionType = value!);
                      },
                    ),
                    const Divider(height: 30),
                    const Text(
                      'Options',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    ...group.options.asMap().entries.map((entry) {
                      int index = entry.key;
                      ModifierOption option = entry.value;
                      return FormFieldRow(
                        spacing: 8,
                        children: [
                          FormFieldRowChild(
                            flex: 3,
                            child: TextFormField(
                              initialValue: option.optionName,
                              decoration: const InputDecoration(
                                labelText: 'Option Name',
                              ),
                              onChanged: (value) => option.optionName = value,
                            ),
                          ),
                          FormFieldRowChild(
                            flex: 2,
                            child: TextFormField(
                              initialValue: option.priceChange.toString(),
                              decoration: const InputDecoration(
                                labelText: 'Price Change',
                              ),
                              keyboardType: TextInputType.number,
                              onChanged: (value) => option.priceChange =
                                  double.tryParse(value) ?? 0.0,
                            ),
                          ),
                        ],
                        trailing: IconButton(
                          icon: const Icon(
                            Icons.remove_circle_outline,
                            color: Colors.red,
                          ),
                          onPressed: () {
                            if (group.options.length > 1) {
                              stfSetState(() => group.options.removeAt(index));
                            }
                          },
                        ),
                      );
                    }),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Option'),
                      onPressed: () {
                        stfSetState(() => group.options.add(ModifierOption()));
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    group.groupName = groupNameController.text;
                    if (group.groupName.isEmpty ||
                        group.options.any((o) => o.optionName.isEmpty)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Group Name and all Option Names are required.',
                          ),
                        ),
                      );
                      return;
                    }

                    if (isNew) {
                      await _firestore
                          .collection('modifierGroups')
                          .add(group.toFirestore());
                    } else {
                      await _firestore
                          .collection('modifierGroups')
                          .doc(group.id)
                          .update(group.toFirestore());
                    }
                    if (mounted) Navigator.of(dialogContext).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier Groups'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('modifierGroups')
            .orderBy('groupName')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No modifier groups found.'));
          }

          final groups = snapshot.data!.docs
              .map((doc) => ModifierGroup.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              final optionsSummary = group.options
                  .map((o) => o.optionName)
                  .join(', ');
              return ListTile(
                title: Text(group.groupName),
                subtitle: Text(
                  'Type: ${group.selectionType} | Options: $optionsSummary',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.edit),
                onTap: () => _showModifierGroupDialog(existingGroup: group),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showModifierGroupDialog(),
        tooltip: 'Add Modifier Group',
        child: const Icon(Icons.add),
      ),
    );
  }
}
