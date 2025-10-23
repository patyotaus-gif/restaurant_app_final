// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugPrint, defaultTargetPlatform, kIsWeb;
import 'package:flutter/services.dart' show ServicesBinding;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:url_strategy/url_strategy.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';

import 'localization/app_localizations.dart';

import 'admin/accounting_export_page.dart';
import 'admin/admin_page.dart';
import 'admin/analytics_page.dart';
import 'admin/audit_log_page.dart';
import 'admin/backoffice_schema_page.dart';
import 'admin/create_purchase_order_page.dart';
import 'admin/customer_profile_page.dart';
import 'admin/employee_management_page.dart';
import 'admin/low_stock_alert_page.dart';
import 'admin/modifier_management_page.dart';
import 'admin/observability_page.dart';
import 'admin/plugins/plugin_provider.dart';
import 'admin/plugins/plugin_registry.dart';
import 'admin/promotion_management_page.dart';
import 'admin/punch_card_management_page.dart';
import 'admin/qa_playbooks_page.dart';
import 'admin/purchase_order_list_page.dart';
import 'admin/reservation_management_page.dart';
import 'admin/stocktake_page.dart';
import 'admin/store_management_page.dart';
import 'admin/supplier_management_page.dart';
import 'admin/time_report_page.dart';
import 'admin/waste_tracking_page.dart';
import 'all_orders_page.dart';
import 'app_mode_provider.dart';
import 'auth_service.dart';
import 'background/background_sync.dart';
import 'cart_page.dart';
import 'cart_provider.dart';
import 'clock_in_out_page.dart';
import 'currency_provider.dart';
import 'customer_menu_page.dart';
import 'dashboard_page.dart';
import 'edit_product_page.dart';
import 'end_of_day_report_page.dart';
import 'feature_flags/feature_flag_provider.dart';
import 'feature_flags/feature_flag_service.dart';
import 'feature_flags/terminal_provider.dart';
import 'firebase_options.dart';
import 'flavor_config.dart';
import 'floor_plan_page.dart';
import 'ingredient_management_page.dart';
import 'kitchen_display_page.dart';
import 'locale_provider.dart';
import 'notification_provider.dart';
import 'notifications_repository.dart';
import 'order_dashboard_page.dart';
import 'order_type_selection_page.dart';
import 'pin_login_page.dart';
import 'product_management_page.dart';
import 'retail_pos_page.dart';
import 'role_selection_page.dart';
import 'security/permission_policy.dart';
import 'services/app_availability_service.dart';
import 'services/audit_log_service.dart';
import 'services/client_cache_service.dart';
import 'services/experiment_service.dart';
import 'services/fx_rate_service.dart';
import 'services/menu_cache_provider.dart';
import 'services/ops_observability_service.dart';
import 'services/performance_metrics_service.dart';
import 'services/payment_gateway_service.dart';
import 'services/print_spooler_service.dart';
import 'services/printer_drawer_service.dart';
import 'services/schema_migration_runner.dart';
import 'services/stocktake_service.dart';
import 'services/store_service.dart';
import 'services/sync_queue_service.dart';
import 'payments/omise_keys.dart';
import 'splash_screen.dart';
import 'stock_provider.dart';
import 'store_provider.dart';
import 'takeaway_orders_page.dart';
import 'theme_provider.dart';
import 'widgets/app_blocked_screen.dart';
import 'widgets/app_snack_bar.dart';
import 'widgets/ops_debug_overlay.dart';
import 'widgets/route_permission_guard.dart';
import 'accessibility_provider.dart';
import 'theme/app_theme.dart';
import 'widgets/accessibility_overlay.dart';

CustomTransitionPage<void> _buildTransitionPage({required Widget child}) {
  return CustomTransitionPage<void>(
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final fadeAnimation = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      final slideAnimation =
          Tween<Offset>(
            begin: const Offset(0.05, 0.02),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            ),
          );

      final scaleAnimation = Tween<double>(begin: 0.98, end: 1).animate(
        CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
          reverseCurve: Curves.easeIn,
        ),
      );

      return FadeTransition(
        opacity: fadeAnimation,
        child: SlideTransition(
          position: slideAnimation,
          child: ScaleTransition(scale: scaleAnimation, child: child),
        ),
      );
    },
  );
}

bool get _supportsRemoteConfig {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    default:
      return false;
  }
}

bool get _supportsFirestore {
  if (kIsWeb) {
    return true;
  }
  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
    case TargetPlatform.windows:
    case TargetPlatform.linux:
      return true;
    default:
      // Other platforms are currently unsupported.
      return false;
  }
}

FirebaseRemoteConfig? _obtainRemoteConfigInstance() {
  if (!_supportsRemoteConfig) {
    debugPrint(
      'Firebase Remote Config is not supported on this platform; using defaults.',
    );
    return null;
  }
  try {
    return FirebaseRemoteConfig.instance;
  } catch (error) {
    debugPrint('Unable to access Firebase Remote Config: $error');
    return null;
  }
}

Future<void> _initializePaymentGateways(
  PaymentGatewayService service, {
  FirebaseRemoteConfig? remoteConfig,
}) async {
  try {
    String publicKey = '';
    String secretKey = '';
    String defaultSourceType = '';

    if (remoteConfig != null) {
      try {
        await remoteConfig.fetchAndActivate();
      } catch (error) {
        debugPrint('Failed to refresh Remote Config for Omise: $error');
      }

      publicKey = remoteConfig.getString('omise_public_key');
      secretKey = remoteConfig.getString('omise_secret_key');
      defaultSourceType = remoteConfig.getString('omise_default_source_type');
    }

    if (publicKey.isEmpty) {
      publicKey = OmiseKeys.publicKey;
    }
    if (secretKey.isEmpty) {
      secretKey = OmiseKeys.secretKey;
    }
    if (defaultSourceType.isEmpty) {
      defaultSourceType = OmiseKeys.defaultSourceType;
    }

    if (publicKey.isEmpty) {
      debugPrint(
        'Skipping Omise configuration because the public key is missing.',
      );
      return;
    }

    if (secretKey.isEmpty) {
      debugPrint(
        'Omise secret key was not provided; proceeding with public key only.',
      );
    }

    service.updateConfig(
      PaymentGatewayType.omise,
      PaymentGatewayConfig(
        apiKey: publicKey,
        secretKey: secretKey.isNotEmpty ? secretKey : null,
        additionalData: <String, dynamic>{
          'publicKey': publicKey,
          if (secretKey.isNotEmpty) 'secretKey': secretKey,
          if (defaultSourceType.isNotEmpty)
            'defaultSourceType': defaultSourceType,
        },
      ),
    );

    service.updateConfig(
      PaymentGatewayType.creditDebitCard,
      PaymentGatewayConfig(
        apiKey: publicKey,
        secretKey: secretKey.isNotEmpty ? secretKey : null,
        additionalData: <String, dynamic>{
          'publicKey': publicKey,
          if (secretKey.isNotEmpty) 'secretKey': secretKey,
          'provider': 'omise',
          if (defaultSourceType.isNotEmpty)
            'defaultSourceType': defaultSourceType,
        },
      ),
    );
  } catch (error) {
    debugPrint('Unable to initialize Omise payment gateway: $error');
  }
}

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const SplashScreen()),
    ),
    GoRoute(
      path: '/login',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const PinLoginPage()),
    ),
    GoRoute(
      path: '/order-type-selection',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const OrderTypeSelectionPage()),
    ),
    GoRoute(
      path: '/retail-pos',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const RetailPosPage()),
    ),
    GoRoute(
      path: '/clock-in-out',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const ClockInOutPage()),
    ),
    GoRoute(
      path: '/roles',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const RoleSelectionPage()),
    ),
    GoRoute(
      path: '/floorplan',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const FloorPlanPage()),
    ),
    GoRoute(
      path: '/takeaway-orders',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const TakeawayOrdersPage()),
    ),
    GoRoute(
      path: '/dashboard',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const OrderDashboardPage()),
    ),
    GoRoute(
      path: '/admin',
      pageBuilder: (context, state) => _buildTransitionPage(
        child: RoutePermissionGuard(
          state: state,
          policy: PermissionPolicy.anyOf({
            Permission.manageStores,
            Permission.manageEmployees,
            Permission.managePurchaseOrders,
            Permission.viewAuditLogs,
            Permission.adjustInventory,
          }),
          builder: (context, state) => const AdminPage(),
        ),
      ),
      routes: [
        GoRoute(
          path: 'reservations',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const ReservationManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'low-stock-alerts',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.viewInventory),
              builder: (context, state) => const LowStockAlertPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'employees',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageEmployees),
              builder: (context, state) => const EmployeeManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'time-report',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageEmployees),
              builder: (context, state) => const TimeReportPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'waste',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.adjustInventory),
              builder: (context, state) => const WasteTrackingPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'promotions',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const PromotionManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'punch-cards',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const PunchCardManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'qa-playbooks',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const QaPlaybooksPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'observability',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.anyOf({
                Permission.manageStores,
                Permission.viewAuditLogs,
              }),
              builder: (context, state) => const ObservabilityPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'modifiers',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const ModifierManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'schema-designer',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const BackofficeSchemaPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'accounting-export',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const AccountingExportPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'customer-profile/:customerId',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) {
                final customerId = state.pathParameters['customerId']!;
                return CustomerProfilePage(customerId: customerId);
              },
            ),
          ),
        ),
        GoRoute(
          path: 'products',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.adjustInventory),
              builder: (context, state) => const ProductManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'products/edit',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.adjustInventory),
              builder: (context, state) {
                final product = state.extra as Product?;
                return EditProductPage(product: product);
              },
            ),
          ),
        ),
        GoRoute(
          path: 'suppliers',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.managePurchaseOrders),
              builder: (context, state) => const SupplierManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'purchase-orders',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.managePurchaseOrders),
              builder: (context, state) => const PurchaseOrderListPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'purchase-orders/create',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.managePurchaseOrders),
              builder: (context, state) => const CreatePurchaseOrderPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'stocktake',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.adjustInventory),
              builder: (context, state) => const StocktakePage(),
            ),
          ),
        ),
        GoRoute(
          path: 'dashboard',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.viewInventory),
              builder: (context, state) => const DashboardPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'eod',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const EndOfDayReportPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'stores',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.manageStores),
              builder: (context, state) => const StoreManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'audit-log',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.viewAuditLogs),
              builder: (context, state) => const AuditLogPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'inventory',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.viewInventory),
              builder: (context, state) => const IngredientManagementPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'analytics',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.anyOf({
                Permission.manageStores,
                Permission.viewInventory,
              }),
              builder: (context, state) => const AnalyticsPage(),
            ),
          ),
        ),
        GoRoute(
          path: 'kds',
          pageBuilder: (context, state) => _buildTransitionPage(
            child: RoutePermissionGuard(
              state: state,
              policy: PermissionPolicy.require(Permission.processSales),
              builder: (context, state) => KitchenDisplayPage(
                initialStationId: state.uri.queryParameters['station'],
              ),
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/all-orders',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const AllOrdersPage()),
    ),
    GoRoute(
      path: '/cart',
      pageBuilder: (context, state) =>
          _buildTransitionPage(child: const CartPage()),
    ),
    GoRoute(
      path: '/table/:tableNumber',
      pageBuilder: (context, state) {
        final tableNumber = state.pathParameters['tableNumber'] ?? 'Unknown';
        return _buildTransitionPage(
          child: CustomerMenuPage(tableNumber: tableNumber),
        );
      },
    ),
  ],
);

Locale _resolveLocale({
  Locale? userPreferred,
  List<Locale>? systemLocales,
  required Iterable<Locale> supportedLocales,
}) {
  if (userPreferred != null) {
    return _matchSupportedLocale(userPreferred, supportedLocales) ??
        supportedLocales.first;
  }

  if (systemLocales != null) {
    for (final locale in systemLocales) {
      final match = _matchSupportedLocale(locale, supportedLocales);
      if (match != null) {
        return match;
      }
    }
  }

  return supportedLocales.first;
}

Locale? _matchSupportedLocale(
  Locale target,
  Iterable<Locale> supportedLocales,
) {
  for (final locale in supportedLocales) {
    final countryMatches =
        (locale.countryCode?.isEmpty ?? true) ||
        locale.countryCode == target.countryCode;
    if (locale.languageCode == target.languageCode && countryMatches) {
      return locale;
    }
  }

  for (final locale in supportedLocales) {
    if (locale.languageCode == target.languageCode) {
      return locale;
    }
  }

  return null;
}

Future<void> main() async {
  OpsObservabilityService? observability;
  return runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      configureBackgroundSync(
        rootIsolateToken: ServicesBinding.rootIsolateToken,
      );
      if (!kIsWeb) {
        if (defaultTargetPlatform == TargetPlatform.windows) {
          try {
            WebView.platform = WindowsWebView();
          } catch (e) {
            debugPrint('Failed to initialize Windows WebView: $e');
          }
        } else if (defaultTargetPlatform == TargetPlatform.macOS) {
          try {
            WebView.platform = WebKitWebView();
          } catch (e) {
            debugPrint('Failed to initialize macOS WebView: $e');
          }
        }
      }
      debugPrint('Launching Restaurant App (${FlavorConfig.flavorName})');
      ensureBackgroundPlugins = () {
        DartPluginRegistrant.ensureInitialized();
      };
      if (kIsWeb) {
        setPathUrlStrategy();
      }
      PluginRegistry.registerDefaults();
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!_supportsFirestore) {
        debugPrint(
          'Firebase Firestore is not supported on this platform; launching '
          'fallback experience.',
        );
        runApp(const UnsupportedPlatformApp());
        return;
      }

      final remoteConfig = _obtainRemoteConfigInstance();

      // Note: the 'settings' setter was removed from newer cloud_firestore versions.
      // Persistence and cache configuration should be handled using the current API.
      // By default, persistence is enabled on mobile platforms; if you need to
      // configure persistence for web or tweak cache size, use the platform-specific
      // APIs provided by the version of cloud_firestore you depend on.

      observability = OpsObservabilityService(FirebaseFirestore.instance);
      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        final logger = observability;
        if (logger != null) {
          unawaited(
            logger.log(
              'Unhandled Flutter framework error',
              level: OpsLogLevel.error,
              error: details.exception,
              stackTrace: details.stack,
              context: const {'phase': 'framework'},
            ),
          );
        }
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        final logger = observability;
        if (logger != null) {
          unawaited(
            logger.log(
              'Uncaught platform dispatcher error',
              level: OpsLogLevel.error,
              error: error,
              stackTrace: stackTrace,
              context: const {'phase': 'platformDispatcher'},
            ),
          );
        }
        return false;
      };

      final packageInfo = await PackageInfo.fromPlatform();
      final availability = AppAvailabilityService(
        remoteConfig,
        observability!,
        packageInfo.buildNumber,
      );
      await availability.initialize();

      await BackgroundSyncManager.instance.registerPeriodicSync();
      runApp(
        MyApp(
          observability: observability!,
          availability: availability,
          remoteConfig: remoteConfig,
        ),
      );
    },
    (error, stackTrace) {
      final logger = observability;
      if (logger != null) {
        unawaited(
          logger.log(
            'Uncaught zone error',
            level: OpsLogLevel.error,
            error: error,
            stackTrace: stackTrace,
            context: const {'phase': 'runZonedGuarded'},
          ),
        );
      } else {
        Zone.current.handleUncaughtError(error, stackTrace);
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    required this.observability,
    required this.availability,
    this.remoteConfig,
    super.key,
  });

  final OpsObservabilityService observability;
  final AppAvailabilityService availability;
  final FirebaseRemoteConfig? remoteConfig;

  @override
  Widget build(BuildContext context) {
    final remoteConfig = this.remoteConfig;
    return MultiProvider(
      providers: [
        Provider<FlavorConfig>.value(value: FlavorConfig.instance),
        ChangeNotifierProvider.value(value: availability),
        ChangeNotifierProvider.value(value: observability),
        Provider<PerformanceMetricsService>(
          create: (_) {
            final functions = FirebaseFunctions.instanceFor(
              app: Firebase.app(),
              region: 'asia-southeast1',
            );
            final service = PerformanceMetricsService(functions);
            unawaited(service.start());
            return service;
          },
          dispose: (_, service) => service.dispose(),
        ),
        ChangeNotifierProvider(create: (ctx) => AppModeProvider()),
        ChangeNotifierProvider(create: (ctx) => AuthService()),
        Provider<ClientCacheService>(create: (_) => ClientCacheService()),
        ChangeNotifierProvider(create: (ctx) => LocaleProvider()),
        Provider<StoreService>(
          create: (_) => StoreService(FirebaseFirestore.instance),
        ),
        Provider<FxRateService>(
          create: (_) => FxRateService(FirebaseFirestore.instance),
        ),
        ChangeNotifierProvider(
          create: (ctx) => MenuCacheProvider(
            FirebaseFirestore.instance,
            ctx.read<ClientCacheService>(),
          ),
        ),
        ChangeNotifierProxyProvider<AuthService, StoreProvider>(
          create: (ctx) => StoreProvider(ctx.read<StoreService>()),
          update: (ctx, auth, previous) {
            final provider =
                previous ?? StoreProvider(ctx.read<StoreService>());
            provider.synchronizeWithAuth(auth);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider<StoreProvider, SchemaMigrationRunner>(
          create: (ctx) => SchemaMigrationRunner(FirebaseFirestore.instance),
          update: (ctx, storeProvider, runner) {
            final service =
                runner ?? SchemaMigrationRunner(FirebaseFirestore.instance);
            service.ensureMigrationsForTenant(
              storeProvider.activeStore?.tenantId,
            );
            return service;
          },
        ),
        ChangeNotifierProxyProvider<StoreProvider, PluginProvider>(
          create: (ctx) => PluginProvider(ctx.read<StoreService>()),
          update: (ctx, storeProvider, pluginProvider) {
            final provider =
                pluginProvider ?? PluginProvider(ctx.read<StoreService>());
            provider.updateStore(storeProvider.activeStore);
            return provider;
          },
        ),
        ChangeNotifierProxyProvider3<
          StoreProvider,
          FxRateService,
          LocaleProvider,
          CurrencyProvider
        >(
          create: (ctx) => CurrencyProvider(ctx.read<FxRateService>()),
          update:
              (
                ctx,
                storeProvider,
                fxService,
                localeProvider,
                currencyProvider,
              ) {
                final provider =
                    currencyProvider ?? CurrencyProvider(fxService);
                provider.applyStore(storeProvider.activeStore);
                provider.updateLocale(localeProvider.locale);
                return provider;
              },
        ),
        ChangeNotifierProvider(create: (ctx) => AccessibilityProvider()),
        ChangeNotifierProvider(create: (ctx) => ThemeProvider()),
        ChangeNotifierProxyProvider<StoreProvider, StockProvider>(
          create: (ctx) => StockProvider(),
          update: (ctx, storeProvider, stockProvider) {
            final provider = stockProvider ?? StockProvider();
            provider.setActiveStore(storeProvider.activeStore?.id);
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => TerminalProvider()),
        Provider<FeatureFlagService>(
          create: (_) => FeatureFlagService(FirebaseFirestore.instance),
        ),
        ChangeNotifierProxyProvider2<
          StoreProvider,
          TerminalProvider,
          FeatureFlagProvider
        >(
          create: (ctx) => FeatureFlagProvider(
            ctx.read<FeatureFlagService>(),
            ctx.read<ClientCacheService>(),
          ),
          update: (ctx, storeProvider, terminalProvider, featureFlagProvider) {
            final provider =
                featureFlagProvider ??
                FeatureFlagProvider(
                  ctx.read<FeatureFlagService>(),
                  ctx.read<ClientCacheService>(),
                );
            provider.updateContext(
              store: storeProvider.activeStore,
              terminalId: terminalProvider.terminalId,
            );
            return provider;
          },
        ),
        ChangeNotifierProxyProvider3<
          FeatureFlagProvider,
          StoreProvider,
          TerminalProvider,
          ExperimentService
        >(
          create: (ctx) => ExperimentService(FirebaseFirestore.instance),
          update:
              (
                ctx,
                featureFlags,
                storeProvider,
                terminalProvider,
                experimentService,
              ) {
                final service =
                    experimentService ??
                    ExperimentService(FirebaseFirestore.instance);
                service.updateConfiguration(featureFlags.configuration);
                service.updateEnvironment(
                  featureFlags.environment,
                  featureFlags.releaseChannel,
                );
                service.updateContext(
                  tenantId: storeProvider.activeStore?.tenantId,
                  storeId: storeProvider.activeStore?.id,
                  terminalId: terminalProvider.terminalId,
                );
                return service;
              },
        ),
        ChangeNotifierProxyProvider<OpsObservabilityService, SyncQueueService>(
          create: (ctx) => SyncQueueService(
            FirebaseFirestore.instance,
            observability: ctx.read<OpsObservabilityService>(),
          ),
          update: (ctx, observability, previous) {
            final service =
                previous ?? SyncQueueService(FirebaseFirestore.instance);
            service.attachObservability(observability);
            if (supportsBackgroundSync()) {
              service.attachBackgroundSyncScheduler(
                ({Duration? delay}) => BackgroundSyncManager.instance
                    .scheduleImmediateSync(delay: delay),
              );
            } else {
              service.attachBackgroundSyncScheduler(null);
            }
            return service;
          },
        ),
        ChangeNotifierProvider(
          create: (_) {
            final service = PaymentGatewayService();
            unawaited(
              _initializePaymentGateways(service, remoteConfig: remoteConfig),
            );
            return service;
          },
        ),
        Provider<PrinterDrawerService>(create: (_) => PrinterDrawerService()),
        Provider<AuditLogService>(
          create: (_) => AuditLogService(FirebaseFirestore.instance),
        ),
        ProxyProvider<AuditLogService, StocktakeService>(
          update: (ctx, auditLogService, previous) {
            return previous ??
                StocktakeService(FirebaseFirestore.instance, auditLogService);
          },
        ),
        Provider<NotificationsRepository>(
          create: (_) => NotificationsRepository(FirebaseFirestore.instance),
        ),
        ChangeNotifierProxyProvider3<
          StoreProvider,
          NotificationsRepository,
          OpsObservabilityService,
          PrintSpoolerService
        >(
          create: (ctx) => PrintSpoolerService(
            printerService: ctx.read<PrinterDrawerService>(),
            notificationsRepository: ctx.read<NotificationsRepository>(),
            observability: ctx.read<OpsObservabilityService>(),
          ),
          update:
              (
                ctx,
                storeProvider,
                notificationsRepository,
                observability,
                previousService,
              ) {
                final service =
                    previousService ??
                    PrintSpoolerService(
                      printerService: ctx.read<PrinterDrawerService>(),
                      notificationsRepository: notificationsRepository,
                      observability: observability,
                    );
                service.updateNotificationsRepository(notificationsRepository);
                service.attachObservability(observability);
                service.updateContext(
                  tenantId: storeProvider.activeStore?.tenantId,
                  storeId: storeProvider.activeStore?.id,
                );
                return service;
              },
        ),
        ChangeNotifierProxyProvider2<
          StockProvider,
          StoreProvider,
          CartProvider
        >(
          create: (ctx) => CartProvider(),
          update: (ctx, stock, storeProvider, previousCart) {
            final cart = previousCart ?? CartProvider();
            cart.update(stock);
            cart.applyStore(storeProvider.activeStore);
            return cart;
          },
        ),
        ChangeNotifierProxyProvider2<
          AuthService,
          StoreProvider,
          NotificationProvider
        >(
          create: (ctx) {
            final repo = ctx.read<NotificationsRepository>();
            final auth = ctx.read<AuthService>();
            final stores = ctx.read<StoreProvider>();
            final uid = auth.loggedInEmployee?.id ?? 'anonymous';
            return NotificationProvider(
              repo: repo,
              uid: uid,
              tenantId: stores.activeStore?.tenantId,
            );
          },
          update: (ctx, auth, storeProvider, previousProvider) {
            final repo = ctx.read<NotificationsRepository>();
            final uid = auth.loggedInEmployee?.id ?? 'anonymous';
            final tenantId = storeProvider.activeStore?.tenantId;
            if (previousProvider != null) {
              previousProvider.updateContext(uid: uid, tenantId: tenantId);
              return previousProvider;
            }
            return NotificationProvider(
              repo: repo,
              uid: uid,
              tenantId: tenantId,
            );
          },
        ),
      ],
      child: Consumer3<ThemeProvider, LocaleProvider, AccessibilityProvider>(
        builder:
            (context, themeProvider, localeProvider, accessibility, child) {
              return MaterialApp.router(
                routerConfig: _router,
                debugShowCheckedModeBanner: false,
                themeMode: themeProvider.themeMode,
                locale: localeProvider.locale,
                supportedLocales: AppLocalizations.supportedLocales,
                localizationsDelegates: const [
                  AppLocalizations.delegate,
                  GlobalMaterialLocalizations.delegate,
                  GlobalCupertinoLocalizations.delegate,
                  GlobalWidgetsLocalizations.delegate,
                ],
                onGenerateTitle: (context) =>
                    AppLocalizations.of(context)!.appTitle,
                localeListResolutionCallback: (locales, supportedLocales) {
                  final resolved = _resolveLocale(
                    userPreferred: localeProvider.locale,
                    systemLocales: locales,
                    supportedLocales: supportedLocales,
                  );
                  Intl.defaultLocale = Intl.canonicalizedLocale(
                    resolved.toLanguageTag(),
                  );
                  return resolved;
                },
                builder: (context, child) {
                  final availabilityService = context
                      .watch<AppAvailabilityService>();
                  switch (availabilityService.status) {
                    case AppAvailabilityStatus.blocked:
                      return AppBlockedScreen(
                        message: availabilityService.message,
                      );
                    case AppAvailabilityStatus.checking:
                      return const Scaffold(
                        body: Center(child: CircularProgressIndicator()),
                      );
                    case AppAvailabilityStatus.available:
                      final mediaQuery = MediaQuery.of(context);
                      final baseScale = mediaQuery.textScaler.scale(1.0);
                      final targetScale =
                          baseScale * accessibility.textScaleFactor;
                      final safeScale =
                          targetScale.isFinite && targetScale > 0.0
                          ? targetScale
                          : 1.0;
                      final scaledChild = MediaQuery(
                        data: mediaQuery.copyWith(
                          textScaler: TextScaler.linear(safeScale),
                          boldText:
                              accessibility.highContrast || mediaQuery.boldText,
                        ),
                        child: child ?? const SizedBox.shrink(),
                      );
                      return AccessibilityOverlayHost(
                        child: OpsDebugOverlayHost(child: scaledChild),
                      );
                  }
                },
                theme: AppTheme.light(accessibility),
                darkTheme: AppTheme.dark(accessibility),
                scaffoldMessengerKey: AppSnackBar.messengerKey,
              );
            },
      ),
    );
  }
}

class UnsupportedPlatformApp extends StatelessWidget {
  const UnsupportedPlatformApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: const [
                Icon(Icons.desktop_windows, size: 48),
                SizedBox(height: 16),
                Text(
                  'This build of Restaurant App is not supported on the '
                  'current platform.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 12),
                Text(
                  'Please use the Android, iOS, macOS, or web version to access '
                  'the full experience.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
