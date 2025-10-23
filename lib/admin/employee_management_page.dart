import 'dart:convert';
import 'package:cryptography/cryptography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:restaurant_models/restaurant_models.dart';

class EmployeeManagementPage extends StatefulWidget {
  const EmployeeManagementPage({super.key});

  @override
  State<EmployeeManagementPage> createState() => _EmployeeManagementPageState();
}

class _EmployeeManagementPageState extends State<EmployeeManagementPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _showEmployeeDialog({Employee? employee}) async {
    final isNew = employee == null;
    final nameController = TextEditingController(text: employee?.name);
    final pinController = TextEditingController(); // PIN is not pre-filled for security
    String selectedRole = employee?.role ?? 'Employee';
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isNew ? 'Add New Employee' : 'Edit Employee'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Name'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  DropdownButtonFormField<String>(
                    value: selectedRole, // Corrected from initialValue
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['Owner', 'Manager', 'Employee', 'Intern']
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() {
                          selectedRole = value;
                        });
                      }
                    },
                  ),
                  TextFormField(
                    controller: pinController,
                    decoration: InputDecoration(
                      labelText: isNew ? '4-Digit PIN' : 'New 4-Digit PIN (optional)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    validator: (value) {
                      if (isNew && (value == null || value.length < 4)) {
                        return 'A 4-digit PIN is required for new employees';
                      }
                      if (!isNew && value != null && value.isNotEmpty && value.length < 4) {
                        return 'PIN must be 4 digits if you want to change it';
                      }
                      return null;
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
              onPressed: () async {
                if (formKey.currentState?.validate() ?? false) {
                  final employeeData = <String, dynamic>{
                    'name': nameController.text,
                    'role': selectedRole,
                  };

                  final pin = pinController.text;
                  if (pin.isNotEmpty) {
                    final algorithm = Sha256();
                    final hashedPinBytes = await algorithm.hash(utf8.encode(pin));
                    employeeData['hashedPin'] = base64Url.encode(hashedPinBytes.bytes);
                  }

                  if (isNew) {
                    await _firestore.collection('employees').add(employeeData);
                  } else {
                    await _firestore
                        .collection('employees')
                        .doc(employee.id)
                        .update(employeeData);
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

  void _deleteEmployee(Employee employee) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: Text('Are you sure you want to delete ${employee.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              _firestore.collection('employees').doc(employee.id).delete();
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee Management'),
        backgroundColor: Colors.indigo,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('employees').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No employees found. Press + to add the first one.'),
            );
          }

          final employees = snapshot.data!.docs
              .map((doc) => Employee.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(employee.name),
                subtitle: Text(employee.role),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _showEmployeeDialog(employee: employee),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteEmployee(employee),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEmployeeDialog(),
        tooltip: 'Add New Employee',
        child: const Icon(Icons.add),
      ),
    );
  }
}
