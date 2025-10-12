class OmiseKeys {
  // รับจาก --dart-define
  static const publicKey = String.fromEnvironment(
    'OMISE_PUBLIC_KEY',
    defaultValue: '',
  );

  static const secretKey = String.fromEnvironment(
    'OMISE_SECRET_KEY',
    defaultValue: '',
  );

  static const defaultSourceType = String.fromEnvironment(
    'OMISE_DEFAULT_SOURCE_TYPE',
    defaultValue: '',
  );
}
