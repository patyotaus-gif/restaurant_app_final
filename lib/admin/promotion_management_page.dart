import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../widgets/form_field_row.dart';

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
    final startTimeController = TextEditingController(
      text: rules.startTime ?? '',
    );
    final endTimeController = TextEditingController(text: rules.endTime ?? '');
    String selectedType = promo?.type ?? 'fixed'; // 'fixed' or 'percentage'
    DateTime? selectedStartDate = rules.startDate;
    DateTime? selectedEndDate = rules.endDate;
    final Set<String> selectedOrderTypes = {...rules.orderTypes};
    final Set<int> selectedWeekdays = {...rules.allowedWeekdays};
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            TimeOfDay? parseTime(String? value) {
              if (value == null || value.isEmpty) return null;
              final parts = value.split(':');
              if (parts.length != 2) return null;
              final hour = int.tryParse(parts[0]);
              final minute = int.tryParse(parts[1]);
              if (hour == null || minute == null) return null;
              if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
                return null;
              }
              return TimeOfDay(hour: hour, minute: minute);
            }

            String formatTime(TimeOfDay time) {
              final hour = time.hour.toString().padLeft(2, '0');
              final minute = time.minute.toString().padLeft(2, '0');
              return '$hour:$minute';
            }

            TimeOfDay? selectedStartTime = parseTime(startTimeController.text);
            TimeOfDay? selectedEndTime = parseTime(endTimeController.text);

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

            Future<void> pickTime({required bool isStart}) async {
              final initialTime = isStart
                  ? selectedStartTime ?? TimeOfDay.now()
                  : selectedEndTime ?? TimeOfDay.now();
              final picked = await showTimePicker(
                context: context,
                initialTime: initialTime,
              );
              if (picked == null) return;
              setStateDialog(() {
                if (isStart) {
                  selectedStartTime = picked;
                  startTimeController.text = formatTime(picked);
                } else {
                  selectedEndTime = picked;
                  endTimeController.text = formatTime(picked);
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

            void toggleWeekday(int weekday, bool checked) {
              setStateDialog(() {
                if (checked) {
                  selectedWeekdays.add(weekday);
                } else {
                  selectedWeekdays.remove(weekday);
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

            Widget buildTimeField({
              required String label,
              required TextEditingController controller,
              required VoidCallback onPick,
            }) {
              return TextFormField(
                controller: controller,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: label,
                  suffixIcon: controller.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            setStateDialog(() {
                              controller.clear();
                              if (controller == startTimeController) {
                                selectedStartTime = null;
                              } else {
                                selectedEndTime = null;
                              }
                            });
                          },
                        )
                      : IconButton(
                          icon: const Icon(Icons.access_time),
                          onPressed: onPick,
                        ),
                ),
                onTap: onPick,
              );
            }

            final weekdayLabels = <int, String>{
              DateTime.monday: 'Mon',
              DateTime.tuesday: 'Tue',
              DateTime.wednesday: 'Wed',
              DateTime.thursday: 'Thu',
              DateTime.friday: 'Fri',
              DateTime.saturday: 'Sat',
              DateTime.sunday: 'Sun',
            };

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
                        initialValue: selectedType,
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
                      const SizedBox(height: 16),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Valid Days (optional)',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      Wrap(
                        spacing: 8,
                        children: weekdayLabels.entries.map((entry) {
                          final isSelected = selectedWeekdays.contains(
                            entry.key,
                          );
                          return FilterChip(
                            label: Text(entry.value),
                            selected: isSelected,
                            onSelected: (value) =>
                                toggleWeekday(entry.key, value),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),
                      FormFieldRow(
                        spacing: 12,
                        children: [
                          FormFieldRowChild(
                            child: buildTimeField(
                              label: 'Start Time (HH:MM)',
                              controller: startTimeController,
                              onPick: () => pickTime(isStart: true),
                            ),
                          ),
                          FormFieldRowChild(
                            child: buildTimeField(
                              label: 'End Time (HH:MM)',
                              controller: endTimeController,
                              onPick: () => pickTime(isStart: false),
                            ),
                          ),
                        ],
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
                      double? parseDouble(String text) =>
                          text.isEmpty ? null : double.tryParse(text);
                      int? parseInt(String text) =>
                          text.isEmpty ? null : int.tryParse(text);

                      final rulesModel = PromotionRules(
                        minSubtotal: parseDouble(minSubtotalController.text),
                        minQuantity: parseInt(minQuantityController.text),
                        requiredCategories: categoryController.text
                            .split(',')
                            .map((e) => e.trim())
                            .where((element) => element.isNotEmpty)
                            .toList(),
                        orderTypes: selectedOrderTypes.toList(),
                        startDate: selectedStartDate,
                        endDate: selectedEndDate,
                        allowedWeekdays: selectedWeekdays.toList()..sort(),
                        startTime: startTimeController.text.trim().isEmpty
                            ? null
                            : startTimeController.text.trim(),
                        endTime: endTimeController.text.trim().isEmpty
                            ? null
                            : endTimeController.text.trim(),
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
