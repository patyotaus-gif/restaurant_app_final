import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../models/permission_policy.dart';
import '../store_provider.dart';
import '../unauthorized_page.dart';

class RoutePermissionGuard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer2<AuthService, StoreProvider>(
      builder: (context, authService, storeProvider, child) {
        final permissionContext = PermissionContext(
          authService: authService,
          storeProvider: storeProvider,
          routerState: state,
        );

        if (!authService.isLoggedIn) {
          if (redirectToLogin) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                context.go('/login');
              }
            });
          }
          return const SizedBox.shrink();
        }

        if (!policy.evaluate(permissionContext)) {
          if (unauthorizedBuilder != null) {
            return unauthorizedBuilder!(context);
          }
          return UnauthorizedPage(
            attemptedRoute: state.uri.toString(),
          );
        }

        return builder(context, state);
      },
    );
  }
}
