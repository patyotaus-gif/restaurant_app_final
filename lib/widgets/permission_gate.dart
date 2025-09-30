import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../auth_service.dart';
import '../security/permission_policy.dart';
import '../store_provider.dart';
class PermissionGate extends StatelessWidget {
  const PermissionGate({
    super.key,
    required this.policy,
    required this.builder,
    this.fallback,
    this.extra,
  });

  final PermissionPolicy policy;
  final WidgetBuilder builder;
  final WidgetBuilder? fallback;
  final Object? extra;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AuthService, StoreProvider>(
      builder: (context, authService, storeProvider, child) {
        final permissionContext = PermissionContext(
          authService: authService,
          storeProvider: storeProvider,
          extras: extra,
        );
        if (policy.evaluate(permissionContext)) {
          return builder(context);
        }
        if (fallback != null) {
          return fallback!(context);
        }
        return const SizedBox.shrink();
      },
    );
  }
}
