import '../models/store_model.dart';
import 'plugin_module.dart';

class PluginRegistry {
  static final Map<String, PluginModule> _modules = {};
  static bool _hasRegisteredDefaults = false;

  static void registerModule(PluginModule module) {
    _modules[module.id] = module;
  }

  static void registerDefaults() {
    if (_hasRegisteredDefaults) {
      return;
    }
    _hasRegisteredDefaults = true;
    registerModule(
      const PluginModule(
        id: 'core-pos',
        name: 'Core POS',
        description:
            'Primary point-of-sale workflows for checkout and ordering.',
        defaultEnabled: true,
      ),
    );
    registerModule(
      const PluginModule(
        id: 'kitchen-display',
        name: 'Kitchen Display System',
        description:
            'Expose the real-time kitchen display station for the store.',
      ),
    );
    registerModule(
      const PluginModule(
        id: 'table-service',
        name: 'Table Service',
        description:
            'Enable table management, floor plans, and dine-in ordering flows.',
        defaultEnabled: true,
      ),
    );
    registerModule(
      const PluginModule(
        id: 'loyalty-program',
        name: 'Loyalty & Membership',
        description:
            'Allow access to loyalty enrolment, membership lookup, and rewards accrual.',
      ),
    );
    registerModule(
      const PluginModule(
        id: 'advanced-analytics',
        name: 'Advanced Analytics',
        description:
            'Unlock enhanced analytics dashboards and exported insights for managers.',
      ),
    );
  }

  static Iterable<PluginModule> get modules sync* {
    final values = _modules.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    yield* values;
  }

  static PluginModule? module(String id) => _modules[id];

  static bool isEnabled(String pluginId, Store? store) {
    final module = _modules[pluginId];
    final defaultEnabled = module?.defaultEnabled ?? false;
    if (store == null) {
      return defaultEnabled;
    }
    return store.pluginOverrides[pluginId] ?? defaultEnabled;
  }
}
