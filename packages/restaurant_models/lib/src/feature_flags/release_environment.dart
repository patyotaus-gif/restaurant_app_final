enum ReleaseEnvironment { development, staging, production }

extension ReleaseEnvironmentName on ReleaseEnvironment {
  String get wireName {
    switch (this) {
      case ReleaseEnvironment.development:
        return 'dev';
      case ReleaseEnvironment.staging:
        return 'stg';
      case ReleaseEnvironment.production:
        return 'prod';
    }
  }
}

ReleaseEnvironment releaseEnvironmentFromName(
  String? value, {
  ReleaseEnvironment fallback = ReleaseEnvironment.production,
}) {
  return tryReleaseEnvironmentFromName(value) ?? fallback;
}

ReleaseEnvironment? tryReleaseEnvironmentFromName(String? value) {
  if (value == null || value.isEmpty) {
    return null;
  }
  final normalized = value.trim().toLowerCase();
  for (final environment in ReleaseEnvironment.values) {
    if (environment.name.toLowerCase() == normalized ||
        environment.wireName == normalized) {
      return environment;
    }
  }
  if (normalized == 'stage' || normalized == 'staging') {
    return ReleaseEnvironment.staging;
  }
  if (normalized == 'prod' || normalized == 'production') {
    return ReleaseEnvironment.production;
  }
  if (normalized == 'dev' || normalized == 'development') {
    return ReleaseEnvironment.development;
  }
  return null;
}

const String kDefaultReleaseChannel = 'prod';
