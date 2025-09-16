// lib/admin/supplier_management_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/supplier_model.dart';

class SupplierManagementPage extends StatefulWidget {
  const SupplierManagementPage({super.key});

  @override
  State<SupplierManagementPage> createState() => _SupplierManagementPageState();
}

class _SupplierManagementPageState extends State<SupplierManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void _showSupplierDialog({Supplier? supplier}) {
    final isNew = supplier == null;
    final nameController = TextEditingController(text: supplier?.name);
    final contactPersonController = TextEditingController(
      text: supplier?.contactPerson,
    );
    final phoneController = TextEditingController(text: supplier?.phoneNumber);
    final emailController = TextEditingController(text: supplier?.email);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add New Supplier' : 'Edit Supplier'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Supplier Name',
                    ),
                    validator: (v) => (v?.isEmpty ?? true) ? 'Required' : null,
                  ),
                  TextFormField(
                    controller: contactPersonController,
                    decoration: const InputDecoration(
                      labelText: 'Contact Person',
                    ),
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                  ),
                  TextFormField(
                    controller: emailController,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                    ),
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
                  final data = {
                    'name': nameController.text,
                    'contactPerson': contactPersonController.text,
                    'phoneNumber': phoneController.text,
                    'email': emailController.text,
                  };

                  if (isNew) {
                    _firestore.collection('suppliers').add(data);
                  } else {
                    _firestore
                        .collection('suppliers')
                        .doc(supplier.id)
                        .update(data);
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
  }

  void _deleteSupplier(String docId) {
    _firestore.collection('suppliers').doc(docId).delete();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Supplier Management')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('suppliers').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No suppliers found.'));
          }

          return ListView(
            children: snapshot.data!.docs.map((doc) {
              final supplier = Supplier.fromFirestore(doc);
              return ListTile(
                title: Text(supplier.name),
                subtitle: Text(supplier.contactPerson),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showSupplierDialog(supplier: supplier),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteSupplier(supplier.id),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showSupplierDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
