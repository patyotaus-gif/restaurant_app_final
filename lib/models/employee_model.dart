import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String name;
  final String role;
  final String pin;
  final List<String> storeIds;
  final Map<String, String> roleByStore;
  final bool isSuperAdmin;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
    required this.storeIds,
    required this.roleByStore,
    required this.isSuperAdmin,
  });

  // Factory constructor to create an Employee from a Firestore document
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      name: data['name'] ?? '',
      role: data['role'] ?? 'Employee',
      pin: data['pin'] ?? '',
      storeIds: List<String>.from(data['storeIds'] ?? const []),
      roleByStore: Map<String, String>.from(
        (data['roleByStore'] as Map?)?.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            ) ??
            {},
      ),
      isSuperAdmin: data['isSuperAdmin'] as bool? ?? false,
    );
  }

  // Method to convert an Employee object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'role': role,
      'pin': pin,
      'storeIds': storeIds,
      'roleByStore': roleByStore,
      'isSuperAdmin': isSuperAdmin,
    };
  }
}
