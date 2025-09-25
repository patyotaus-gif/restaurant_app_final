import 'dart:convert';

import 'package:restaurant_models/restaurant_models.dart';
class FeatureFlagConfiguration {
  const FeatureFlagConfiguration({
    required EnvironmentConfiguration global,
    required this.environments,
    required this.releaseChannels,
    required this.experiments,
  }) : _global = global;

  final EnvironmentConfiguration _global;
  final Map<ReleaseEnvironment, EnvironmentConfiguration> environments;
  final Map<String, ReleaseChannelConfiguration> releaseChannels;
  final Map<String, ExperimentDefinition> experiments;

  static const String defaultReleaseChannel = kDefaultReleaseChannel;

  Map<String, bool> get tenantFlags => _global.tenantFlags;
  Map<String, Map<String, bool>> get storeFlags => _global.storeFlags;
  Map<String, Map<String, bool>> get terminalFlags => _global.terminalFlags;

  EnvironmentConfiguration get global => _global;

  factory FeatureFlagConfiguration.empty() => FeatureFlagConfiguration(
    global: EnvironmentConfiguration.empty(),
    environments: const {},
    releaseChannels: const {},
    experiments: const {},
  );

  factory FeatureFlagConfiguration.fromMap(Map<String, dynamic> data) {
    EnvironmentConfiguration parseEnvironment(dynamic value) {
      if (value is Map<String, dynamic>) {
        return EnvironmentConfiguration.fromMap(value);
      }
      return EnvironmentConfiguration.empty();
    }

    final global = EnvironmentConfiguration.fromFlatMap(data);

    final envs = <ReleaseEnvironment, EnvironmentConfiguration>{};
    final rawEnvironments = data['environments'] as Map<String, dynamic>?;
    if (rawEnvironments != null) {
      rawEnvironments.forEach((key, dynamic value) {
        final environment = tryReleaseEnvironmentFromName(key);
        if (environment != null) {
          envs[environment] = parseEnvironment(value);
        }
      });
    }

    final channels = <String, ReleaseChannelConfiguration>{};
    final rawChannels = data['releaseChannels'] as Map<String, dynamic>?;
    if (rawChannels != null) {
      rawChannels.forEach((key, dynamic value) {
        if (value is Map<String, dynamic>) {
          channels[key] = ReleaseChannelConfiguration.fromMap(value);
        }
      });
    }

    final experimentMap = <String, ExperimentDefinition>{};
    final rawExperiments = data['experiments'] as Map<String, dynamic>?;
    if (rawExperiments != null) {
      rawExperiments.forEach((key, dynamic value) {
        if (value is Map<String, dynamic>) {
          experimentMap[key] = ExperimentDefinition.fromMap(key, value);
        }
      });
    }

    return FeatureFlagConfiguration(
      global: global,
      environments: envs,
      releaseChannels: channels,
      experiments: experimentMap,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'flags': tenantFlags,
      'stores': storeFlags,
      'terminals': terminalFlags,
      if (_global.rollouts.isNotEmpty)
        'rollouts': _global.rollouts.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
      if (environments.isNotEmpty)
        'environments': environments.map(
          (key, value) => MapEntry(key.wireName, value.toMap()),
        ),
      if (releaseChannels.isNotEmpty)
        'releaseChannels': releaseChannels.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
      if (experiments.isNotEmpty)
        'experiments': experiments.map(
          (key, value) => MapEntry(key, value.toMap()),
        ),
    };
  }

  ReleaseEnvironment resolveEnvironment(
    ReleaseEnvironment requested,
    String? releaseChannel,
  ) {
    if (releaseChannel != null && releaseChannels.containsKey(releaseChannel)) {
      final channelConfig = releaseChannels[releaseChannel];
      if (channelConfig?.environment != null) {
        return channelConfig!.environment!;
      }
    }
    return requested;
  }

  Map<String, bool> effectiveFlags({
    String? storeId,
    String? terminalId,
    ReleaseEnvironment? environment,
    String? releaseChannel,
    String? rolloutUnitId,
  }) {
    final resolvedEnvironment = resolveEnvironment(
      environment ?? ReleaseEnvironment.production,
      releaseChannel,
    );
    final environmentConfig = environments[resolvedEnvironment];
    final releaseConfig = releaseChannel != null
        ? releaseChannels[releaseChannel]
        : null;

    final merged = Map<String, bool>.from(
      _global.collectFlags(storeId: storeId, terminalId: terminalId),
    );
    if (environmentConfig != null) {
      merged.addAll(
        environmentConfig.collectFlags(
          storeId: storeId,
          terminalId: terminalId,
        ),
      );
    }
    if (releaseConfig != null && releaseConfig.flagOverrides.isNotEmpty) {
      merged.addAll(releaseConfig.flagOverrides);
    }

    final unitId = (rolloutUnitId ?? terminalId ?? storeId ?? '').trim();

    final rolloutMap = <String, StagedRollout>{}
      ..addAll(_global.rollouts)
      ..addAll(environmentConfig?.rollouts ?? const {})
      ..addAll(releaseConfig?.rollouts ?? const {});

    if (rolloutMap.isNotEmpty) {
      rolloutMap.forEach((flag, rollout) {
        final baseValue = merged[flag] ?? false;
        final resolved = rollout.apply(
          unitId: unitId,
          fallback: baseValue,
          cohortKey: flag,
        );
        merged[flag] = resolved;
      });
    }

    return merged;
  }

  bool isEnabled(
    String flag, {
    String? storeId,
    String? terminalId,
    ReleaseEnvironment? environment,
    String? releaseChannel,
    String? rolloutUnitId,
  }) {
    final effective = effectiveFlags(
      storeId: storeId,
      terminalId: terminalId,
      environment: environment,
      releaseChannel: releaseChannel,
      rolloutUnitId: rolloutUnitId,
    );
    return effective[flag] ?? false;
  }

  ExperimentDefinition? resolveExperiment(
    String experimentId, {
    required ReleaseEnvironment environment,
    String? releaseChannel,
  }) {
    final definition = experiments[experimentId];
    if (definition == null) {
      return null;
    }
    final resolvedEnvironment = resolveEnvironment(environment, releaseChannel);
    if (!definition.isEligible(resolvedEnvironment, releaseChannel)) {
      return null;
    }
    return definition;
  }

  Iterable<ExperimentDefinition> eligibleExperiments({
    required ReleaseEnvironment environment,
    String? releaseChannel,
  }) {
    return experiments.values.where(
      (experiment) => experiment.isEligible(
        resolveEnvironment(environment, releaseChannel),
        releaseChannel,
      ),
    );
  }
}

class EnvironmentConfiguration {
  const EnvironmentConfiguration({
    required this.tenantFlags,
    required this.storeFlags,
    required this.terminalFlags,
    required this.rollouts,
  });

  final Map<String, bool> tenantFlags;
  final Map<String, Map<String, bool>> storeFlags;
  final Map<String, Map<String, bool>> terminalFlags;
  final Map<String, StagedRollout> rollouts;

  factory EnvironmentConfiguration.empty() => const EnvironmentConfiguration(
    tenantFlags: {},
    storeFlags: {},
    terminalFlags: {},
    rollouts: {},
  );

  factory EnvironmentConfiguration.fromFlatMap(Map<String, dynamic> data) {
    return EnvironmentConfiguration(
      tenantFlags: _toBoolMap(data['flags']),
      storeFlags: _toNestedMap(data['stores']),
      terminalFlags: _toNestedMap(data['terminals']),
      rollouts: _toRolloutMap(data['rollouts']),
    );
  }

  factory EnvironmentConfiguration.fromMap(Map<String, dynamic> data) {
    return EnvironmentConfiguration(
      tenantFlags: _toBoolMap(data['flags']),
      storeFlags: _toNestedMap(data['stores']),
      terminalFlags: _toNestedMap(data['terminals']),
      rollouts: _toRolloutMap(data['rollouts']),
    );
  }

  Map<String, bool> collectFlags({String? storeId, String? terminalId}) {
    final merged = Map<String, bool>.from(tenantFlags);
    if (storeId != null && storeFlags.containsKey(storeId)) {
      merged.addAll(storeFlags[storeId]!);
    }
    if (terminalId != null && terminalFlags.containsKey(terminalId)) {
      merged.addAll(terminalFlags[terminalId]!);
    }
    return merged;
  }

  Map<String, dynamic> toMap() {
    return {
      'flags': tenantFlags,
      'stores': storeFlags,
      'terminals': terminalFlags,
      if (rollouts.isNotEmpty)
        'rollouts': rollouts.map((key, value) => MapEntry(key, value.toMap())),
    };
  }
}

class ReleaseChannelConfiguration {
  const ReleaseChannelConfiguration({
    this.environment,
    this.flagOverrides = const {},
    this.rollouts = const {},
  });

  final ReleaseEnvironment? environment;
  final Map<String, bool> flagOverrides;
  final Map<String, StagedRollout> rollouts;

  factory ReleaseChannelConfiguration.fromMap(Map<String, dynamic> data) {
    final environmentName = data['environment'] as String?;
    return ReleaseChannelConfiguration(
      environment: tryReleaseEnvironmentFromName(environmentName),
      flagOverrides: _toBoolMap(data['flags']),
      rollouts: _toRolloutMap(data['rollouts']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (environment != null) 'environment': environment!.wireName,
      if (flagOverrides.isNotEmpty) 'flags': flagOverrides,
      if (rollouts.isNotEmpty)
        'rollouts': rollouts.map((key, value) => MapEntry(key, value.toMap())),
    };
  }
}

class StagedRollout {
  const StagedRollout({
    required this.percentage,
    this.value = true,
    this.seed,
    this.rolloutId,
  });

  final double percentage;
  final bool value;
  final String? seed;
  final String? rolloutId;

  factory StagedRollout.fromMap(Map<String, dynamic> data) {
    final rawPercentage = data['percentage'] ?? data['percent'];
    double percentage;
    if (rawPercentage is int) {
      percentage = rawPercentage.toDouble();
    } else if (rawPercentage is double) {
      percentage = rawPercentage;
    } else if (rawPercentage is String) {
      percentage = double.tryParse(rawPercentage) ?? 0;
    } else {
      percentage = 0;
    }
    if (percentage > 1) {
      percentage = percentage / 100.0;
    }
    percentage = percentage.clamp(0.0, 1.0);
    final value = data['value'] == null ? true : data['value'] == true;
    final seed = data['seed'] as String?;
    final rolloutId = data['id'] as String?;
    return StagedRollout(
      percentage: percentage,
      value: value,
      seed: seed,
      rolloutId: rolloutId,
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{'percentage': percentage, 'value': value};
    if (seed != null) {
      map['seed'] = seed;
    }
    if (rolloutId != null) {
      map['id'] = rolloutId;
    }
    return map;
  }

  bool includes(String unitId, {String? cohortKey}) {
    if (percentage <= 0) {
      return false;
    }
    if (percentage >= 1) {
      return true;
    }
    final trimmed = unitId.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    final resolvedSeed = _composeSeed(cohortKey);
    final hash = _stableHashDouble('$resolvedSeed::$trimmed');
    return hash < percentage;
  }

  bool apply({
    required String unitId,
    required bool fallback,
    String? cohortKey,
  }) {
    if (!includes(unitId, cohortKey: cohortKey)) {
      return fallback;
    }
    return value;
  }

  String _composeSeed(String? cohortKey) {
    final buffer = StringBuffer('rollout');
    if (seed != null && seed!.isNotEmpty) {
      buffer.write('::$seed');
    }
    if (rolloutId != null && rolloutId!.isNotEmpty) {
      buffer.write('::$rolloutId');
    }
    if (cohortKey != null && cohortKey.isNotEmpty) {
      buffer.write('::$cohortKey');
    }
    return buffer.toString();
  }
}

class ExperimentDefinition {
  ExperimentDefinition({
    required this.id,
    required Map<String, double> variants,
    this.seed,
    Set<ReleaseEnvironment>? environments,
    Set<String>? channels,
    this.rollout,
    this.metadata = const {},
    String? defaultVariant,
  }) : variants = _normalizeVariants(variants),
       environments = environments ?? ReleaseEnvironment.values.toSet(),
       channels = channels ?? const {},
       defaultVariant =
           defaultVariant ??
           (variants.isNotEmpty ? variants.keys.first : 'control');

  final String id;
  final Map<String, double> variants;
  final String? seed;
  final Set<ReleaseEnvironment> environments;
  final Set<String> channels;
  final StagedRollout? rollout;
  final Map<String, dynamic> metadata;
  final String defaultVariant;

  factory ExperimentDefinition.fromMap(String id, Map<String, dynamic> data) {
    final rawVariants = data['variants'];
    Map<String, double> variants;
    if (rawVariants is Map<String, dynamic>) {
      variants = rawVariants.map((key, dynamic value) {
        if (value is num) {
          return MapEntry(key, value.toDouble());
        }
        if (value is String) {
          return MapEntry(key, double.tryParse(value) ?? 0.0);
        }
        return MapEntry(key, 0.0);
      });
    } else {
      variants = const {'control': 1.0};
    }

    final envList = (data['environments'] as List<dynamic>?)
        ?.map((dynamic value) => tryReleaseEnvironmentFromName('$value'))
        .whereType<ReleaseEnvironment>()
        .toSet();
    final singleEnvironment = data['environment'] is String
        ? tryReleaseEnvironmentFromName(data['environment'] as String?)
        : null;
    final normalizedEnvironments =
        envList ?? (singleEnvironment != null ? {singleEnvironment} : null);

    final channelSet =
        (data['channels'] as List<dynamic>?)
            ?.map((dynamic value) => '$value')
            .where((value) => value.isNotEmpty)
            .toSet() ??
        <String>{};

    final rolloutData = data['rollout'];
    final rollout = rolloutData is Map<String, dynamic>
        ? StagedRollout.fromMap(rolloutData)
        : null;

    return ExperimentDefinition(
      id: id,
      variants: variants,
      seed: data['seed'] as String?,
      environments: normalizedEnvironments,
      channels: channelSet.isEmpty ? null : channelSet,
      rollout: rollout,
      metadata: (data['metadata'] as Map<String, dynamic>?) ?? const {},
      defaultVariant: data['defaultVariant'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'variants': variants,
      if (seed != null) 'seed': seed,
      if (environments.length != ReleaseEnvironment.values.length)
        'environments': environments.map((env) => env.wireName).toList(),
      if (channels.isNotEmpty) 'channels': channels.toList(),
      if (rollout != null) 'rollout': rollout!.toMap(),
      if (metadata.isNotEmpty) 'metadata': metadata,
      if (defaultVariant.isNotEmpty) 'defaultVariant': defaultVariant,
    };
  }

  bool isEligible(ReleaseEnvironment environment, String? releaseChannel) {
    if (!environments.contains(environment)) {
      return false;
    }
    if (channels.isEmpty) {
      return true;
    }
    if (releaseChannel == null) {
      return false;
    }
    return channels.contains(releaseChannel);
  }

  String assignVariant(String subjectKey) {
    if (variants.isEmpty) {
      return defaultVariant;
    }

    final resolvedSeed = _composeSeed();
    final hash = _stableHashDouble('$resolvedSeed::$subjectKey');

    double cumulative = 0;
    String? selected;
    variants.forEach((variant, weight) {
      if (selected != null) {
        return;
      }
      cumulative += weight;
      if (hash <= cumulative) {
        selected = variant;
      }
    });
    return selected ?? variants.keys.last;
  }

  bool isSubjectEligible(String subjectKey) {
    if (rollout == null) {
      return true;
    }
    return rollout!.includes(subjectKey, cohortKey: id);
  }

  String _composeSeed() {
    final buffer = StringBuffer('experiment::$id');
    if (seed != null && seed!.isNotEmpty) {
      buffer.write('::$seed');
    }
    return buffer.toString();
  }
}

Map<String, bool> _toBoolMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map(
      (key, dynamic flagValue) => MapEntry(key, flagValue == true),
    );
  }
  return const {};
}

Map<String, Map<String, bool>> _toNestedMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map(
      (key, dynamic nested) => MapEntry(key, _toBoolMap(nested)),
    );
  }
  return const {};
}

Map<String, StagedRollout> _toRolloutMap(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value.map((key, dynamic rolloutData) {
      if (rolloutData is Map<String, dynamic>) {
        return MapEntry(key, StagedRollout.fromMap(rolloutData));
      }
      return MapEntry(key, const StagedRollout(percentage: 0));
    });
  }
  return const {};
}

Map<String, double> _normalizeVariants(Map<String, double> variants) {
  if (variants.isEmpty) {
    return const {'control': 1.0};
  }
  double total = variants.values.fold(0.0, (sum, weight) => sum + weight);
  if (total <= 0) {
    total = variants.length.toDouble();
    return variants.map((key, value) => MapEntry(key, 1 / total));
  }
  return variants.map(
    (key, value) => MapEntry(key, value <= 0 ? 0 : value / total),
  );
}

int _stableHash(String input) {
  const int fnvPrime = 16777619;
  const int fnvOffset = 2166136261;
  int hash = fnvOffset;
  for (final codeUnit in utf8.encode(input)) {
    hash ^= codeUnit;
    hash = (hash * fnvPrime) & 0xFFFFFFFF;
  }
  return hash;
}

double _stableHashDouble(String input) {
  const double twoTo32 = 4294967296.0;
  final hash = _stableHash(input);
  return (hash & 0xFFFFFFFF) / twoTo32;
}
