// lib/customer_lookup_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart'; // <-- Import intl for date formatting
import '../models/customer_model.dart';

class CustomerLookupPage extends StatefulWidget {
  const CustomerLookupPage({super.key});

  @override
  State<CustomerLookupPage> createState() => _CustomerLookupPageState();
}

class _CustomerLookupPageState extends State<CustomerLookupPage> {
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  DocumentSnapshot? _foundCustomerDoc;
  bool _isLoading = false;
  String? _message;
  DateTime? _selectedBirthDate; // <-- 1. Add state variable for birthday

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _searchCustomer() async {
    if (_phoneController.text.isEmpty) return;
    setState(() {
      _isLoading = true;
      _message = null;
      _foundCustomerDoc = null;
    });

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('customers')
          .where('phoneNumber', isEqualTo: _phoneController.text)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        setState(() {
          _foundCustomerDoc = querySnapshot.docs.first;
        });
      } else {
        setState(() {
          _message = 'Customer not found. You can create a new one.';
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _createNewCustomer() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });

      try {
        final newCustomerRef = await FirebaseFirestore.instance
            .collection('customers')
            .add({
              'name': _nameController.text,
              'phoneNumber': _phoneController.text,
              'loyaltyPoints': 0,
              'joinDate': Timestamp.now(),
              'tier': 'Silver',
              'lifetimeSpend': 0.0,
              // --- 2. Add birthDate to the saved data ---
              'birthDate': _selectedBirthDate != null
                  ? Timestamp.fromDate(_selectedBirthDate!)
                  : null,
            });

        final newCustomerDoc = await newCustomerRef.get();
        if (mounted) {
          context.pop(newCustomerDoc);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to create customer: $e')),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  // --- 3. Add a function to show the date picker ---
  Future<void> _selectBirthDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedBirthDate ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedBirthDate) {
      setState(() {
        _selectedBirthDate = picked;
      });
    }
  }

  Widget _buildTierChip(String tier) {
    Color chipColor;
    switch (tier) {
      case 'Gold':
        chipColor = Colors.amber.shade700;
        break;
      case 'Platinum':
        chipColor = Colors.blueGrey.shade600;
        break;
      default: // Silver
        chipColor = Colors.grey.shade600;
    }
    return Chip(
      label: Text(
        tier,
        style: const TextStyle(color: Colors.white, fontSize: 10),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Find / Add Customer')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            TextField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: 'Customer Phone Number',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _searchCustomer,
                ),
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            if (_isLoading) const CircularProgressIndicator(),
            if (_message != null && _foundCustomerDoc == null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        Text(_message!, textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'New Customer Name',
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please enter a name'
                              : null,
                        ),
                        // --- 4. Add the UI for birth date selection ---
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.cake),
                          title: const Text('Date of Birth (Optional)'),
                          subtitle: Text(
                            _selectedBirthDate == null
                                ? 'Not set'
                                : DateFormat(
                                    'dd MMMM yyyy',
                                  ).format(_selectedBirthDate!),
                          ),
                          onTap: () => _selectBirthDate(context),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.person_add),
                          label: const Text('Create New Customer'),
                          onPressed: _createNewCustomer,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_foundCustomerDoc != null)
              Builder(
                builder: (context) {
                  final customer = Customer.fromFirestore(_foundCustomerDoc!);
                  return Card(
                    color: Colors.green.shade100,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        context.push('/admin/customer-profile/${customer.id}');
                      },
                      child: ListTile(
                        leading: const Icon(
                          Icons.check_circle,
                          color: Colors.green,
                        ),
                        title: Row(
                          children: [
                            Text(customer.name),
                            const SizedBox(width: 8),
                            _buildTierChip(customer.tier),
                          ],
                        ),
                        subtitle: Text('Points: ${customer.loyaltyPoints}'),
                        trailing: ElevatedButton(
                          child: const Text('Select'),
                          onPressed: () {
                            context.pop(_foundCustomerDoc);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
