// lib/main.dart

import 'dart:async';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/src/widgets/binding.dart' show DartPluginRegistrant;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:url_strategy/url_strategy.dart';

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
import 'admin/plugins/plugin_provider.dart';
import 'admin/plugins/plugin_registry.dart';
import 'admin/promotion_management_page.dart';
import 'admin/punch_card_management_page.dart';
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

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const PinLoginPage()),
    GoRoute(
      path: '/order-type-selection',
      builder: (context, state) => const OrderTypeSelectionPage(),
    ),
    GoRoute(
      path: '/retail-pos',
      builder: (context, state) => const RetailPosPage(),
    ),
    GoRoute(
      path: '/clock-in-out',
      builder: (context, state) => const ClockInOutPage(),
    ),
    GoRoute(
      path: '/roles',
      builder: (context, state) => const RoleSelectionPage(),
    ),
    GoRoute(
      path: '/floorplan',
      builder: (context, state) => const FloorPlanPage(),
    ),
    GoRoute(
      path: '/takeaway-orders',
      builder: (context, state) => const TakeawayOrdersPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) => const OrderDashboardPage(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => RoutePermissionGuard(
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
      routes: [
        GoRoute(
          path: 'reservations',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const ReservationManagementPage(),
          ),
        ),
        GoRoute(
          path: 'low-stock-alerts',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.viewInventory),
            builder: (context, state) => const LowStockAlertPage(),
          ),
        ),
        GoRoute(
          path: 'employees',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageEmployees),
            builder: (context, state) => const EmployeeManagementPage(),
          ),
        ),
        GoRoute(
          path: 'time-report',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageEmployees),
            builder: (context, state) => const TimeReportPage(),
          ),
        ),
        GoRoute(
          path: 'waste',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.adjustInventory),
            builder: (context, state) => const WasteTrackingPage(),
          ),
        ),
        GoRoute(
          path: 'promotions',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const PromotionManagementPage(),
          ),
        ),
        GoRoute(
          path: 'punch-cards',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const PunchCardManagementPage(),
          ),
        ),
        GoRoute(
          path: 'modifiers',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const ModifierManagementPage(),
          ),
        ),
        GoRoute(
          path: 'schema-designer',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const BackofficeSchemaPage(),
          ),
        ),
        GoRoute(
          path: 'accounting-export',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const AccountingExportPage(),
          ),
        ),
        GoRoute(
          path: 'customer-profile/:customerId',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) {
              final customerId = state.pathParameters['customerId']!;
              return CustomerProfilePage(customerId: customerId);
            },
          ),
        ),
        GoRoute(
          path: 'products',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.adjustInventory),
            builder: (context, state) => const ProductManagementPage(),
          ),
        ),
        GoRoute(
          path: 'products/edit',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.adjustInventory),
            builder: (context, state) {
              final product = state.extra as Product?;
              return EditProductPage(product: product);
            },
          ),
        ),
        GoRoute(
          path: 'suppliers',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.managePurchaseOrders),
            builder: (context, state) => const SupplierManagementPage(),
          ),
        ),
        GoRoute(
          path: 'purchase-orders',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.managePurchaseOrders),
            builder: (context, state) => const PurchaseOrderListPage(),
          ),
        ),
        GoRoute(
          path: 'purchase-orders/create',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.managePurchaseOrders),
            builder: (context, state) => const CreatePurchaseOrderPage(),
          ),
        ),
        GoRoute(
          path: 'stocktake',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.adjustInventory),
            builder: (context, state) => const StocktakePage(),
          ),
        ),
        GoRoute(
          path: 'dashboard',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.viewInventory),
            builder: (context, state) => const DashboardPage(),
          ),
        ),
        GoRoute(
          path: 'eod',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const EndOfDayReportPage(),
          ),
        ),
        GoRoute(
          path: 'stores',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.manageStores),
            builder: (context, state) => const StoreManagementPage(),
          ),
        ),
        GoRoute(
          path: 'audit-log',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.viewAuditLogs),
            builder: (context, state) => const AuditLogPage(),
          ),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.viewInventory),
            builder: (context, state) => const IngredientManagementPage(),
          ),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.anyOf({
              Permission.manageStores,
              Permission.viewInventory,
            }),
            builder: (context, state) => const AnalyticsPage(),
          ),
        ),
        GoRoute(
          path: 'kds',
          builder: (context, state) => RoutePermissionGuard(
            state: state,
            policy: PermissionPolicy.require(Permission.processSales),
            builder: (context, state) => KitchenDisplayPage(
              initialStationId: state.uri.queryParameters['station'],
            ),
          ),
        ),
      ],
    ),
    GoRoute(
      path: '/all-orders',
      builder: (context, state) => const AllOrdersPage(),
    ),
    GoRoute(path: '/cart', builder: (context, state) => const CartPage()),
    GoRoute(
      path: '/table/:tableNumber',
      builder: (context, state) {
        final tableNumber = state.pathParameters['tableNumber'] ?? 'Unknown';
        return CustomerMenuPage(tableNumber: tableNumber);
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
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
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
        FirebaseRemoteConfig.instance,
        observability!,
        packageInfo.buildNumber,
      );
      await availability.initialize();

      await BackgroundSyncManager.instance.registerPeriodicSync();
      runApp(
        MyApp(
          observability: observability!,
          availability: availability,
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
      }
    },
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    required this.observability,
    required this.availability,
    super.key,
  });

  final OpsObservabilityService observability;
  final AppAvailabilityService availability;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
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
            service.attachBackgroundSyncScheduler(
              ({Duration? delay}) => BackgroundSyncManager.instance
                  .scheduleImmediateSync(delay: delay),
            );
            return service;
          },
        ),
        ChangeNotifierProvider(create: (_) => PaymentGatewayService()),
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
              final availabilityService =
                  context.watch<AppAvailabilityService>();
              switch (availabilityService.status) {
                case AppAvailabilityStatus.blocked:
                  return AppBlockedScreen(
                    message: availabilityService.message,
                  );
                case AppAvailabilityStatus.checking:
                  return const Scaffold(
                    body: Center(
                      child: CircularProgressIndicator(),
                    ),
                  );
                case AppAvailabilityStatus.available:
                  final mediaQuery = MediaQuery.of(context);
                  final scaledChild = MediaQuery(
                    data: mediaQuery.copyWith(
                      textScaleFactor: accessibility.textScaleFactor,
                      boldText: accessibility.highContrast || mediaQuery.boldText,
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
