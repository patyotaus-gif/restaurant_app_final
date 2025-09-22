class FeatureFlagConfiguration {
  final Map<String, bool> tenantFlags;
  final Map<String, Map<String, bool>> storeFlags;
  final Map<String, Map<String, bool>> terminalFlags;

  const FeatureFlagConfiguration({
    required this.tenantFlags,
    required this.storeFlags,
    required this.terminalFlags,
  });

  factory FeatureFlagConfiguration.empty() => const FeatureFlagConfiguration(
    tenantFlags: {},
    storeFlags: {},
    terminalFlags: {},
  );

  factory FeatureFlagConfiguration.fromMap(Map<String, dynamic> data) {
    Map<String, bool> _toBoolMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map(
          (key, dynamic flagValue) => MapEntry(key, flagValue == true),
        );
      }
      return {};
    }

    Map<String, Map<String, bool>> _toNestedMap(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value.map(
          (key, dynamic nested) => MapEntry(key, _toBoolMap(nested)),
        );
      }
      return {};
    }

    return FeatureFlagConfiguration(
      tenantFlags: _toBoolMap(data['flags']),
      storeFlags: _toNestedMap(data['stores']),
      terminalFlags: _toNestedMap(data['terminals']),
    );
  }

  bool isEnabled(String flag, {String? storeId, String? terminalId}) {
    final effective = effectiveFlags(storeId: storeId, terminalId: terminalId);
    return effective[flag] ?? false;
  }

  Map<String, bool> effectiveFlags({String? storeId, String? terminalId}) {
    final merged = Map<String, bool>.from(tenantFlags);
    if (storeId != null && storeFlags.containsKey(storeId)) {
      merged.addAll(storeFlags[storeId]!);
    }
    if (terminalId != null && terminalFlags.containsKey(terminalId)) {
      merged.addAll(terminalFlags[terminalId]!);
    }
    return merged;
  }
}
