import 'package:cloud_firestore/cloud_firestore.dart';

class Store {
  final String id;
  final String name;
  final String? address;
  final bool isActive;
  final String? timezone;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.isActive = true,
    this.timezone,
  });

  factory Store.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Store(
      id: doc.id,
      name: data['name'] as String? ?? 'Unnamed Store',
      address: data['address'] as String?,
      isActive: data['isActive'] as bool? ?? true,
      timezone: data['timezone'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      if (address != null) 'address': address,
      'isActive': isActive,
      if (timezone != null) 'timezone': timezone,
    };
  }
}
