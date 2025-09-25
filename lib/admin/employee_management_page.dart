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

  void _showEmployeeDialog({Employee? employee}) {
    final isNew = employee == null;
    final nameController = TextEditingController(text: employee?.name);
    final pinController = TextEditingController(text: employee?.pin);
    String selectedRole = employee?.role ?? 'Employee';
    final formKey = GlobalKey<FormState>();

    showDialog(
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
                    initialValue:
                        selectedRole, // FIX: Changed 'value' to 'initialValue'
                    decoration: const InputDecoration(labelText: 'Role'),
                    items: ['Owner', 'Manager', 'Employee', 'Intern']
                        .map(
                          (role) =>
                              DropdownMenuItem(value: role, child: Text(role)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        selectedRole = value;
                      }
                    },
                  ),
                  TextFormField(
                    controller: pinController,
                    decoration: const InputDecoration(labelText: '4-Digit PIN'),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: 4,
                    validator: (value) {
                      if (value == null || value.length < 4) {
                        return 'PIN must be 4 digits';
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
              onPressed: () {
                if (formKey.currentState?.validate() ?? false) {
                  final employeeData = {
                    'name': nameController.text,
                    'role': selectedRole,
                    'pin': pinController.text,
                  };

                  if (isNew) {
                    _firestore.collection('employees').add(employeeData);
                  } else
                    _firestore
                        .collection('employees')
                        .doc(employee.id)
                        .update(employeeData);

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
