import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';

import 'auth_service.dart';
import 'models/employee_model.dart';
import 'models/role_permission_model.dart';
import 'models/store_model.dart';
import 'services/store_service.dart';

class StoreProvider with ChangeNotifier {
  StoreProvider(this._storeService);

  final StoreService _storeService;
  StreamSubscription<List<Store>>? _storeSubscription;
  Employee? _currentEmployee;

  List<Store> _stores = [];
  Store? _activeStore;
  bool _isLoading = false;

  List<Store> get stores => _stores;
  Store? get activeStore => _activeStore;
  bool get isLoading => _isLoading;

  void synchronizeWithAuth(AuthService authService) {
    final employee = authService.loggedInEmployee;
    if (_currentEmployee?.id != employee?.id) {
      _currentEmployee = employee;
      _listenForStores();
    }

    if (_activeStore != null && authService.activeStoreId != _activeStore!.id) {
      authService.setActiveStore(_activeStore!.id);
    } else if (_activeStore == null && authService.activeStoreId != null) {
      final matchingStore = _stores.firstWhereOrNull(
        (store) => store.id == authService.activeStoreId,
      );
      if (matchingStore != null) {
        _activeStore = matchingStore;
        notifyListeners();
      }
    }
  }

  void _listenForStores() {
    _storeSubscription?.cancel();
    if (_currentEmployee == null) {
      _stores = [];
      _activeStore = null;
      notifyListeners();
      return;
    }
    _isLoading = true;
    notifyListeners();
    final storeIds = _currentEmployee!.isSuperAdmin
        ? null
        : _currentEmployee!.storeIds;
    if (storeIds != null && storeIds.isEmpty) {
      _stores = [];
      _activeStore = null;
      _isLoading = false;
      notifyListeners();
      return;
    }
    _storeSubscription = _storeService.watchStores(storeIds: storeIds).listen((
      stores,
    ) {
      _stores = stores;
      if (_stores.isEmpty) {
        _activeStore = null;
      } else if (_activeStore == null ||
          !_stores.any((store) => store.id == _activeStore!.id)) {
        _activeStore = _stores.first;
      }
      _isLoading = false;
      notifyListeners();
    });
  }

  void setActiveStore(Store? store, AuthService authService) {
    if (_activeStore?.id == store?.id) {
      return;
    }
    _activeStore = store;
    authService.setActiveStore(store?.id);
    notifyListeners();
  }

  Future<void> refreshRoleOverrides() async {
    await _storeService.loadRoleOverrides();
    notifyListeners();
  }

  Future<void> persistRoleOverrides(
    Map<String, Set<Permission>> customRoles,
  ) async {
    await _storeService.persistRoleOverrides(customRoles);
    await refreshRoleOverrides();
  }

  @override
  void dispose() {
    _storeSubscription?.cancel();
    super.dispose();
  }
}
