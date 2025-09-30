import 'package:go_router/go_router.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart';
import '../store_provider.dart';
class PermissionContext {
  PermissionContext({
    required this.authService,
    required this.storeProvider,
    this.routerState,
    this.extras,
  });

  final AuthService authService;
  final StoreProvider storeProvider;
  final GoRouterState? routerState;
  final Object? extras;

  Store? get activeStore => storeProvider.activeStore;
  String? get activeStoreId => authService.activeStoreId;
  bool get isLoggedIn => authService.isLoggedIn;
  bool get isSuperAdmin => authService.loggedInEmployee?.isSuperAdmin == true;

  bool hasPermission(Permission permission) =>
      authService.hasPermission(permission);

  /// Attempts to cast the provided [extras] to the requested type.
  T? extraAs<T>() {
    final value = extras;
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Convenience helper for working with [extras] represented as a map.
  ///
  /// Returns the value for [key] when it can be safely cast to [T]. When the
  /// structure is not a map or the value cannot be cast the method returns
  /// `null`.
  T? extraValue<T>(String key) {
    final value = extras;
    if (value is Map<String, dynamic>) {
      final candidate = value[key];
      if (candidate is T) {
        return candidate;
      }
      return null;
    }
    if (value is Map) {
      final dynamic candidate = value[key];
      if (candidate is T) {
        return candidate;
      }
      return null;
    }
    return null;
  }
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

  static PermissionPolicy storeAssignment({String? storeIdKey}) {
    return PermissionPolicy._((context) {
      final employee = context.authService.loggedInEmployee;
      if (employee == null) {
        return false;
      }

      final targetStoreId = _resolveStoreId(context, storeIdKey);
      if (targetStoreId == null) {
        return false;
      }
      return employee.storeIds.contains(targetStoreId);
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

  static String? _resolveStoreId(
    PermissionContext context,
    String? storeIdKey,
  ) {
    final extra = context.extras;
    if (extra is Store) {
      return extra.id.isEmpty ? null : extra.id;
    }
    if (extra is String && extra.isNotEmpty) {
      return extra;
    }
    if (extra is Map) {
      if (storeIdKey != null) {
        final dynamic keyed = extra[storeIdKey];
        if (keyed is String && keyed.isNotEmpty) {
          return keyed;
        }
      }
      final dynamic explicit = extra['storeId'] ?? extra['id'];
      if (explicit is String && explicit.isNotEmpty) {
        return explicit;
      }
    }

    if (storeIdKey != null) {
      final fromExtras = context.extraValue<String>(storeIdKey);
      if (fromExtras != null && fromExtras.isNotEmpty) {
        return fromExtras;
      }
    }

    final routeStoreId =
        context.routerState?.pathParameters[storeIdKey ?? 'storeId'];
    if (routeStoreId != null && routeStoreId.isNotEmpty) {
      return routeStoreId;
    }

    final activeStoreId = context.activeStoreId;
    if (activeStoreId != null && activeStoreId.isNotEmpty) {
      return activeStoreId;
    }
    return null;
  }
}
