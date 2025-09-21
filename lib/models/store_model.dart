import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String name;
  final String? address;
  final String? taxId;
  final String? phone;
  final String? email;
  final bool isActive;
  final String? timezone;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.taxId,
    this.phone,
    this.email,
    this.isActive = true,
    this.timezone,
  });

  factory Store.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Store(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Store',
      address: data['address'] as String?,
      taxId: data['taxId'] as String?,
      phone: data['phone'] as String?,
      email: data['email'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      timezone: data['timezone'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (address != null) 'address': address,
      if (taxId != null) 'taxId': taxId,
      if (phone != null) 'phone': phone,
      if (email != null) 'email': email,
      'isActive': isActive,
      if (timezone != null) 'timezone': timezone,
    };
  }
}
