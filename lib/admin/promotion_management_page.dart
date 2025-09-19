import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/promotion_model.dart';

class PromotionManagementPage extends StatefulWidget {
  const PromotionManagementPage({super.key});

  @override
  State<PromotionManagementPage> createState() =>
      _PromotionManagementPageState();
}

class _PromotionManagementPageState extends State<PromotionManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // --- 1. ฟังก์ชันสำหรับแสดง Dialog (เพิ่ม/แก้ไข) ---
  void _showPromotionDialog({Promotion? promo}) {
    final isNew = promo == null;
    final rules = promo?.rules ?? const PromotionRules();
    final codeController = TextEditingController(text: promo?.code);
    final descriptionController = TextEditingController(
      text: promo?.description,
    );
    final valueController = TextEditingController(
      text: promo?.value.toString(),
    );
    final minSubtotalController = TextEditingController(
      text: rules.minSubtotal?.toString() ?? '',
    );
    final minQuantityController = TextEditingController(
      text: rules.minQuantity?.toString() ?? '',
    );
    final categoryController = TextEditingController(
      text: rules.requiredCategories.join(', '),
    );
    final startDateController = TextEditingController(
      text: rules.startDate != null
          ? DateFormat('yyyy-MM-dd').format(rules.startDate!)
          : '',
    );
    final endDateController = TextEditingController(
      text: rules.endDate != null
          ? DateFormat('yyyy-MM-dd').format(rules.endDate!)
          : '',
    );
    String selectedType = promo?.type ?? 'fixed'; // 'fixed' or 'percentage'
    DateTime? selectedStartDate = rules.startDate;
    DateTime? selectedEndDate = rules.endDate;
    final Set<String> selectedOrderTypes = {...rules.orderTypes};
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            Future<void> pickDate({required bool isStart}) async {
              final initialDate = isStart
                  ? selectedStartDate ?? DateTime.now()
                  : selectedEndDate ?? DateTime.now();
              final firstDate = DateTime.now().subtract(
                const Duration(days: 365 * 5),
              );
              final lastDate = DateTime.now().add(
                const Duration(days: 365 * 5),
              );
              final selected = await showDatePicker(
                context: context,
                initialDate: initialDate,
                firstDate: firstDate,
                lastDate: lastDate,
              );
              setStateDialog(() {
                if (isStart) {
                  selectedStartDate = selected;
                  startDateController.text = selected != null
                      ? DateFormat('yyyy-MM-dd').format(selected)
                      : '';
                } else {
                  selectedEndDate = selected;
                  endDateController.text = selected != null
                      ? DateFormat('yyyy-MM-dd').format(selected)
                      : '';
                }
              });
            }

            void toggleOrderType(String type, bool checked) {
              setStateDialog(() {
                if (checked) {
                  selectedOrderTypes.add(type);
                } else {
                  selectedOrderTypes.remove(type);
                }
              });
            }

            Widget buildDateField({
              required String label,
              required TextEditingController controller,
              required VoidCallback onPick,
              required VoidCallback onClear,
              required bool hasValue,
            }) {
              return TextFormField(
                controller: controller,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: label,
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (hasValue)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: onClear,
                        ),
                      IconButton(
                        icon: const Icon(Icons.calendar_today),
                        onPressed: onPick,
                      ),
                    ],
                  ),
                ),
                onTap: onPick,
              );
            }

            return AlertDialog(
              title: Text(isNew ? 'Add New Promotion' : 'Edit Promotion'),
              content: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: codeController,
                        decoration: const InputDecoration(
                          labelText: 'Promotion Code (e.g., SAVE10)',
                        ),
                        textCapitalization: TextCapitalization.characters,
                        validator: (value) => (value?.isEmpty ?? true)
                            ? 'Please enter a code'
                            : null,
                      ),
                      TextFormField(
                        controller: descriptionController,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                        ),
                        validator: (value) => (value?.isEmpty ?? true)
                            ? 'Please enter a description'
                            : null,
                      ),
                      DropdownButtonFormField<String>(
                        value: selectedType,
                        decoration: const InputDecoration(
                          labelText: 'Discount Type',
                        ),
                        items: ['fixed', 'percentage']
                            .map(
                              (type) => DropdownMenuItem(
                                value: type,
                                child: Text(
                                  type == 'fixed'
                                      ? 'Fixed Amount (Baht)'
                                      : 'Percentage (%)',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setStateDialog(() {
                              selectedType = value;
                            });
                          }
                        },
                      ),
                      TextFormField(
                        controller: valueController,
                        decoration: const InputDecoration(
                          labelText: 'Discount Value',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter a value';
                          }
                          if (double.tryParse(value) == null) {
                            return 'Please enter a valid number';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Eligibility Rules (optional)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      TextFormField(
                        controller: minSubtotalController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Subtotal (Baht)',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}'),
                          ),
                        ],
                      ),
                      TextFormField(
                        controller: minQuantityController,
                        decoration: const InputDecoration(
                          labelText: 'Minimum Total Items',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      TextFormField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Required Categories (comma separated)',
                        ),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Valid for Dine-in orders'),
                        value: selectedOrderTypes.contains('dineIn'),
                        onChanged: (checked) =>
                            toggleOrderType('dineIn', checked ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Valid for Takeaway orders'),
                        value: selectedOrderTypes.contains('takeaway'),
                        onChanged: (checked) =>
                            toggleOrderType('takeaway', checked ?? false),
                      ),
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Valid for Retail orders'),
                        value: selectedOrderTypes.contains('retail'),
                        onChanged: (checked) =>
                            toggleOrderType('retail', checked ?? false),
                      ),
                      buildDateField(
                        label: 'Start Date',
                        controller: startDateController,
                        hasValue: selectedStartDate != null,
                        onPick: () => pickDate(isStart: true),
                        onClear: () {
                          setStateDialog(() {
                            selectedStartDate = null;
                            startDateController.clear();
                          });
                        },
                      ),
                      buildDateField(
                        label: 'End Date',
                        controller: endDateController,
                        hasValue: selectedEndDate != null,
                        onPick: () => pickDate(isStart: false),
                        onClear: () {
                          setStateDialog(() {
                            selectedEndDate = null;
                            endDateController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      double? _parseDouble(String text) =>
                          text.isEmpty ? null : double.tryParse(text);
                      int? _parseInt(String text) =>
                          text.isEmpty ? null : int.tryParse(text);

                      final rulesModel = PromotionRules(
                        minSubtotal: _parseDouble(minSubtotalController.text),
                        minQuantity: _parseInt(minQuantityController.text),
                        requiredCategories: categoryController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((element) => element.isNotEmpty)
                            .toList(),
                        orderTypes: selectedOrderTypes.toList(),
                        startDate: selectedStartDate,
                        endDate: selectedEndDate,
                      );

                      final promoData = {
                        'code': codeController.text
                            .toUpperCase(), // Store code in uppercase for consistency
                        'description': descriptionController.text,
                        'type': selectedType,
                        'value': double.parse(valueController.text),
                        'rules': rulesModel.toMap(),
                        // For new promotions, isActive defaults to false.
                        // For existing ones, its value is not changed here.
                      };

                      if (isNew) {
                        promoData['isActive'] =
                            false; // New promos are inactive by default
                        _firestore.collection('promotions').add(promoData);
                      } else {
                        _firestore
                            .collection('promotions')
                            .doc(promo.id)
                            .update(promoData);
                      }
                      Navigator.of(context).pop();
                    }
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
        title: const Text('Promotion Management'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('promotions').orderBy('code').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No promotions found. Press + to add one.'),
            );
          }

          final promotions = snapshot.data!.docs
              .map((doc) => Promotion.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: promotions.length,
            itemBuilder: (context, index) {
              final promo = promotions[index];
              final ruleSummary = promo.rules.summary();
              return ListTile(
                leading: const Icon(Icons.local_offer_outlined),
                title: Text(
                  promo.code,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(promo.description),
                    if (ruleSummary.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text(
                          ruleSummary,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                  ],
                ),
                trailing: Switch(
                  value: promo.isActive,
                  onChanged: (bool value) {
                    _firestore.collection('promotions').doc(promo.id).update({
                      'isActive': value,
                    });
                  },
                ),
                // --- 2. Connect ListTile to the Edit function ---
                onTap: () {
                  _showPromotionDialog(promo: promo);
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        // --- 3. Connect FAB to the Add function ---
        onPressed: () {
          _showPromotionDialog();
        },
        tooltip: 'Add New Promotion',
        child: const Icon(Icons.add),
      ),
    );
  }
}
