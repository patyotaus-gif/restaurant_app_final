class PluginModule {
  final String id;
  final String name;
  final String description;
  final bool defaultEnabled;

  const PluginModule({
    required this.id,
    required this.name,
    required this.description,
    this.defaultEnabled = false,
  });
}
