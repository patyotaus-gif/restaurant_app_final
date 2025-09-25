import 'package:go_router/go_router.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart';
import '../store_provider.dart';
class PermissionContext {
  PermissionContext({
    required this.authService,
    required this.storeProvider,
    this.routerState,
  });

  final AuthService authService;
  final StoreProvider storeProvider;
  final GoRouterState? routerState;

  Store? get activeStore => storeProvider.activeStore;
  String? get activeStoreId => authService.activeStoreId;
  bool get isLoggedIn => authService.isLoggedIn;
  bool get isSuperAdmin => authService.loggedInEmployee?.isSuperAdmin == true;

  bool hasPermission(Permission permission) =>
      authService.hasPermission(permission);
}

typedef _PolicyEvaluator = bool Function(PermissionContext context);

class PermissionPolicy {
  const PermissionPolicy._(this._evaluator);

  final _PolicyEvaluator _evaluator;

  bool evaluate(PermissionContext context) {
    if (!context.isLoggedIn) {
      return false;
    }
    if (context.isSuperAdmin) {
      return true;
    }
    return _evaluator(context);
  }

  static PermissionPolicy allowAll() =>
      PermissionPolicy._((_) => true);

  static PermissionPolicy denyAll() =>
      PermissionPolicy._((_) => false);

  static PermissionPolicy require(Permission permission) {
    return PermissionPolicy._((context) => context.hasPermission(permission));
  }

  static PermissionPolicy anyOf(Iterable<Permission> permissions) {
    final perms = permissions.toSet();
    return PermissionPolicy._((context) {
      for (final permission in perms) {
        if (context.hasPermission(permission)) {
          return true;
        }
      }
      return false;
    });
  }

  static PermissionPolicy allOf(Iterable<Permission> permissions) {
    final perms = permissions.toSet();
    return PermissionPolicy._(
        (context) => perms.every((permission) => context.hasPermission(permission)));
  }

  static PermissionPolicy role(String roleName) {
    final normalized = roleName.toLowerCase();
    return PermissionPolicy._(
      (context) =>
          (context.authService.activeRoleName ?? '').toLowerCase() == normalized,
    );
  }

  static PermissionPolicy storeAssignment() {
    return PermissionPolicy._((context) {
      final employee = context.authService.loggedInEmployee;
      final activeStoreId = context.activeStoreId;
      if (employee == null || activeStoreId == null) {
        return false;
      }
      return employee.storeIds.contains(activeStoreId);
    });
  }

  static PermissionPolicy custom(bool Function(PermissionContext context) evaluator) {
    return PermissionPolicy._(evaluator);
  }

  PermissionPolicy and(PermissionPolicy other) {
    return PermissionPolicy._(
      (context) => evaluate(context) && other.evaluate(context),
    );
  }

  PermissionPolicy or(PermissionPolicy other) {
    return PermissionPolicy._(
      (context) => evaluate(context) || other.evaluate(context),
    );
  }

  PermissionPolicy operator &(PermissionPolicy other) => and(other);

  PermissionPolicy operator |(PermissionPolicy other) => or(other);

  PermissionPolicy negate() =>
      PermissionPolicy._((context) => !evaluate(context));
}
