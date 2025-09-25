import 'package:cloud_firestore/cloud_firestore.dart';

import 'currency_settings.dart';
import 'feature_flags/release_environment.dart';
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
  final CurrencySettings currencySettings;
  final ReleaseEnvironment releaseEnvironment;
  final String releaseChannel;

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
    this.currencySettings = const CurrencySettings(),
    this.releaseEnvironment = ReleaseEnvironment.production,
    this.releaseChannel = kDefaultReleaseChannel,
  });

  factory Store.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final releaseData = data['release'] as Map<String, dynamic>?;
    final releaseEnvironmentName =
        releaseData?['environment'] as String? ?? data['releaseEnvironment'] as String?;
    final releaseChannel = releaseData?['channel'] as String? ??
        data['releaseChannel'] as String? ?? kDefaultReleaseChannel;
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
      currencySettings: data['currencySettings'] == null
          ? const CurrencySettings()
          : CurrencySettings.fromMap(
              Map<String, dynamic>.from(
                data['currencySettings'] as Map<String, dynamic>,
              ),
            ),
      releaseEnvironment:
          releaseEnvironmentFromName(releaseEnvironmentName),
      releaseChannel: releaseChannel.isEmpty
          ? kDefaultReleaseChannel
          : releaseChannel,
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
      if (currencySettings != const CurrencySettings())
        'currencySettings': currencySettings.toMap(),
      'release': {
        'environment': releaseEnvironment.wireName,
        'channel': releaseChannel,
      },
    };
  }

  bool isPluginEnabled(String pluginId, {bool defaultValue = false}) {
    return pluginOverrides[pluginId] ?? defaultValue;
  }

  Store copyWith({
    String? id,
    String? name,
    String? address,
    String? taxId,
    String? phone,
    String? email,
    bool? isActive,
    String? timezone,
    String? tenantId,
    Map<String, bool>? pluginOverrides,
    TaxConfiguration? taxConfiguration,
    bool? houseAccountsEnabled,
    CurrencySettings? currencySettings,
    ReleaseEnvironment? releaseEnvironment,
    String? releaseChannel,
  }) {
    return Store(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      taxId: taxId ?? this.taxId,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      isActive: isActive ?? this.isActive,
      timezone: timezone ?? this.timezone,
      tenantId: tenantId ?? this.tenantId,
      pluginOverrides: pluginOverrides ?? this.pluginOverrides,
      taxConfiguration: taxConfiguration ?? this.taxConfiguration,
      houseAccountsEnabled:
          houseAccountsEnabled ?? this.houseAccountsEnabled,
      currencySettings: currencySettings ?? this.currencySettings,
      releaseEnvironment: releaseEnvironment ?? this.releaseEnvironment,
      releaseChannel: releaseChannel ?? this.releaseChannel,
    );
  }
}
