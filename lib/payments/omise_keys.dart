class OmiseKeys {
  // รับจาก --dart-define
  static const publicKey = String.fromEnvironment(
    'OMISE_PUBLIC_KEY',
    defaultValue: '',
  );
}
