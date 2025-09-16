import 'package:cloud_firestore/cloud_firestore.dart';

class Employee {
  final String id;
  final String name;
  final String role;
  final String pin;

  Employee({
    required this.id,
    required this.name,
    required this.role,
    required this.pin,
  });

  // Factory constructor to create an Employee from a Firestore document
  factory Employee.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Employee(
      id: doc.id,
      name: data['name'] ?? '',
      role: data['role'] ?? 'Employee',
      pin: data['pin'] ?? '',
    );
  }

  // Method to convert an Employee object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {'name': name, 'role': role, 'pin': pin};
  }
}
