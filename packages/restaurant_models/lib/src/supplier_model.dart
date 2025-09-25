// lib/models/supplier_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
class Supplier {
  final String id;
  final String name;
  final String contactPerson;
  final String phoneNumber;
  final String email;

  Supplier({
    required this.id,
    required this.name,
    this.contactPerson = '',
    this.phoneNumber = '',
    this.email = '',
  });

  factory Supplier.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Supplier(
      id: doc.id,
      name: data['name'] ?? '',
      contactPerson: data['contactPerson'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      email: data['email'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'contactPerson': contactPerson,
      'phoneNumber': phoneNumber,
      'email': email,
    };
  }
}
