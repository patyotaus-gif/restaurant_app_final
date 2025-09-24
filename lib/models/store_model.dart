import 'package:cloud_firestore/cloud_firestore.dart';

import 'tax_model.dart';

class Store {
  final String id;
  final String name;
  final String? address;
  final String? taxId;
  final String? phone;
  final String? email;
  final bool isActive;
  final String? timezone;
  final String tenantId;
  final Map<String, bool> pluginOverrides;
  final TaxConfiguration? taxConfiguration;
  final bool houseAccountsEnabled;

  const Store({
    required this.id,
    required this.name,
    this.address,
    this.taxId,
    this.phone,
    this.email,
    this.isActive = true,
    this.timezone,
    this.tenantId = 'default',
    this.pluginOverrides = const {},
    this.taxConfiguration,
    this.houseAccountsEnabled = false,
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
      tenantId: data['tenantId'] as String? ?? 'default',
      pluginOverrides: Map<String, bool>.from(
        (data['pluginOverrides'] as Map<String, dynamic>? ?? const {}).map(
          (key, dynamic value) => MapEntry(key, value == true),
        ),
      ),
      taxConfiguration: data['taxConfiguration'] == null
          ? null
          : TaxConfiguration.fromMap(
              Map<String, dynamic>.from(
                data['taxConfiguration'] as Map<String, dynamic>,
              ),
            ),
      houseAccountsEnabled: data['houseAccountsEnabled'] == true,
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
      'tenantId': tenantId,
      if (pluginOverrides.isNotEmpty) 'pluginOverrides': pluginOverrides,
      if (taxConfiguration != null)
        'taxConfiguration': taxConfiguration!.toMap(),
      'houseAccountsEnabled': houseAccountsEnabled,
    };
  }

  bool isPluginEnabled(String pluginId, {bool defaultValue = false}) {
    return pluginOverrides[pluginId] ?? defaultValue;
  }
}
