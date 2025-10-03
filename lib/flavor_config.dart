enum AppFlavor { dev, stg, prod }

class FlavorConfig {
  const FlavorConfig._({required this.flavor, required this.name});

  final AppFlavor flavor;
  final String name;

  static FlavorConfig? _instance;

  static void configure({required AppFlavor flavor}) {
    switch (flavor) {
      case AppFlavor.dev:
        _instance = const FlavorConfig._(flavor: AppFlavor.dev, name: 'Development');
        break;
      case AppFlavor.stg:
        _instance = const FlavorConfig._(flavor: AppFlavor.stg, name: 'Staging');
        break;
      case AppFlavor.prod:
        _instance = const FlavorConfig._(flavor: AppFlavor.prod, name: 'Production');
        break;
    }
  }

  static FlavorConfig get instance =>
      _instance ?? const FlavorConfig._(flavor: AppFlavor.prod, name: 'Production');

  static String get flavorName => instance.name;
}
