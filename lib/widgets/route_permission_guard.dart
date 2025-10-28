import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../security/permission_policy.dart';
import '../store_provider.dart';
import '../unauthorized_page.dart';
class RoutePermissionGuard extends StatefulWidget {
  const RoutePermissionGuard({
    super.key,
    required this.state,
    required this.policy,
    required this.builder,
    this.redirectToLogin = true,
    this.unauthorizedBuilder,
  });

  final GoRouterState state;
  final PermissionPolicy policy;
  final Widget Function(BuildContext context, GoRouterState state) builder;
  final bool redirectToLogin;
  final WidgetBuilder? unauthorizedBuilder;

  @override
  State<RoutePermissionGuard> createState() => _RoutePermissionGuardState();
}

class _RoutePermissionGuardState extends State<RoutePermissionGuard> {
  bool _redirectScheduled = false;

  void _scheduleLoginRedirect(BuildContext context) {
    if (_redirectScheduled) {
      return;
    }
    _redirectScheduled = true;
    Future.microtask(() {
      if (!context.mounted) {
        return;
      }
      context.go('/login');
    });
  }

  void _resetRedirectFlagIfNeeded(bool isLoggedIn) {
    if (isLoggedIn) {
      _redirectScheduled = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, StoreProvider>(
      builder: (context, authService, storeProvider, child) {
        _resetRedirectFlagIfNeeded(authService.isLoggedIn);

        final permissionContext = PermissionContext(
          authService: authService,
          storeProvider: storeProvider,
          routerState: widget.state,
          extras: widget.state.extra,
        );

        if (!authService.isLoggedIn) {
          if (widget.redirectToLogin) {
            _scheduleLoginRedirect(context);
          }
          return const SizedBox.shrink();
        }

        if (!widget.policy.evaluate(permissionContext)) {
          if (widget.unauthorizedBuilder != null) {
            return widget.unauthorizedBuilder!(context);
          }
          return UnauthorizedPage(
            attemptedRoute: widget.state.uri.toString(),
          );
        }

        return widget.builder(context, widget.state);
      },
    );
  }
}
