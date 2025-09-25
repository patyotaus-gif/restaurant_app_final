import 'package:flutter/foundation.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../../services/store_service.dart';
import 'plugin_module.dart';
import 'plugin_registry.dart';
class PluginProvider with ChangeNotifier {
  PluginProvider(this._storeService);

  final StoreService _storeService;

  Store? _activeStore;
  Map<String, bool>? _localOverrides;

  Store? get activeStore => _activeStore;

  Iterable<PluginModule> get availableModules => PluginRegistry.modules;

  Map<String, bool> get effectivePluginStates {
    final overrides =
        _localOverrides ?? _activeStore?.pluginOverrides ?? const {};
    return {
      for (final module in availableModules)
        module.id: overrides[module.id] ?? module.defaultEnabled,
    };
  }

  bool isEnabled(String pluginId) {
    final module = PluginRegistry.module(pluginId);
    final defaultEnabled = module?.defaultEnabled ?? false;
    final overrides =
        _localOverrides ?? _activeStore?.pluginOverrides ?? const {};
    return overrides[pluginId] ?? defaultEnabled;
  }

  void updateStore(Store? store) {
    final hasChanged =
        _activeStore?.id != store?.id ||
        !mapEquals(_activeStore?.pluginOverrides, store?.pluginOverrides);
    if (!hasChanged) {
      return;
    }
    _activeStore = store;
    _localOverrides = null;
    notifyListeners();
  }

  Future<void> setPluginState(String pluginId, bool isEnabled) async {
    final store = _activeStore;
    if (store == null) {
      throw StateError('Cannot toggle plugins without an active store.');
    }
    final overrides = Map<String, bool>.from(
      _localOverrides ?? store.pluginOverrides,
    )..[pluginId] = isEnabled;
    _localOverrides = overrides;
    notifyListeners();
    await _storeService.setPluginOverrides(store.id, overrides);
  }
}
