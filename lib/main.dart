// lib/main.dart

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:url_strategy/url_strategy.dart';

import 'firebase_options.dart';
import 'cart_provider.dart';
import 'auth_service.dart';
import 'splash_screen.dart';
import 'theme_provider.dart';
import 'stock_provider.dart';
import 'notifications_repository.dart';
import 'notification_provider.dart';
import 'services/sync_queue_service.dart';
import 'services/client_cache_service.dart';

import 'customer_menu_page.dart';
import 'role_selection_page.dart';
import 'pin_login_page.dart';
import 'floor_plan_page.dart';
import 'order_dashboard_page.dart';
import 'admin/admin_page.dart';
import 'all_orders_page.dart';
import 'product_management_page.dart';
import 'edit_product_page.dart';
import 'dashboard_page.dart';
import 'end_of_day_report_page.dart';
import 'ingredient_management_page.dart';
import 'kitchen_display_page.dart';
import 'cart_page.dart';
import 'models/product_model.dart';
import 'admin/employee_management_page.dart';
import 'admin/waste_tracking_page.dart';
import 'admin/promotion_management_page.dart';
import 'admin/accounting_export_page.dart';
import 'admin/low_stock_alert_page.dart';
import 'admin/customer_profile_page.dart';
import 'admin/reservation_management_page.dart';
import 'order_type_selection_page.dart';
import 'takeaway_orders_page.dart';
import 'app_mode_provider.dart';
import 'retail_pos_page.dart';
import 'admin/supplier_management_page.dart';
import 'admin/purchase_order_list_page.dart';
import 'admin/create_purchase_order_page.dart';
import 'clock_in_out_page.dart';
import 'admin/time_report_page.dart';
import 'admin/punch_card_management_page.dart';
import 'admin/modifier_management_page.dart'; // <-- ADDED THIS IMPORT
import 'admin/stocktake_page.dart';
import 'admin/store_management_page.dart';
import 'admin/audit_log_page.dart';
import 'admin/analytics_page.dart';
import 'store_provider.dart';
import 'services/store_service.dart';
import 'services/audit_log_service.dart';
import 'services/stocktake_service.dart';
import 'services/payment_gateway_service.dart';
import 'services/menu_cache_provider.dart';
import 'services/printer_drawer_service.dart';
import 'services/schema_migration_runner.dart';
import 'feature_flags/feature_flag_provider.dart';
import 'feature_flags/feature_flag_service.dart';
import 'feature_flags/terminal_provider.dart';
import 'admin/plugins/plugin_provider.dart';
import 'admin/plugins/plugin_registry.dart';

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
      builder: (context, state) => const AdminPage(),
      routes: [
        GoRoute(
          path: 'reservations',
          builder: (context, state) => const ReservationManagementPage(),
        ),
        GoRoute(
          path: 'low-stock-alerts',
          builder: (context, state) => const LowStockAlertPage(),
        ),
        GoRoute(
          path: 'employees',
          builder: (context, state) => const EmployeeManagementPage(),
        ),
        GoRoute(
          path: 'time-report',
          builder: (context, state) => const TimeReportPage(),
        ),
        GoRoute(
          path: 'waste',
          builder: (context, state) => const WasteTrackingPage(),
        ),
        GoRoute(
          path: 'promotions',
          builder: (context, state) => const PromotionManagementPage(),
        ),
        GoRoute(
          path: 'punch-cards',
          builder: (context, state) => const PunchCardManagementPage(),
        ),
        // --- ADDED THIS NEW ROUTE ---
        GoRoute(
          path: 'modifiers',
          builder: (context, state) => const ModifierManagementPage(),
        ),
        // -----------------------------
        GoRoute(
          path: 'accounting-export',
          builder: (context, state) => const AccountingExportPage(),
        ),
        GoRoute(
          path: 'customer-profile/:customerId',
          builder: (context, state) {
            final customerId = state.pathParameters['customerId']!;
            return CustomerProfilePage(customerId: customerId);
          },
        ),
        GoRoute(
          path: 'products',
          builder: (context, state) => const ProductManagementPage(),
        ),
        GoRoute(
          path: 'products/edit',
          builder: (context, state) {
            final product = state.extra as Product?;
            return EditProductPage(product: product);
          },
        ),
        GoRoute(
          path: 'suppliers',
          builder: (context, state) => const SupplierManagementPage(),
        ),
        GoRoute(
          path: 'purchase-orders',
          builder: (context, state) => const PurchaseOrderListPage(),
        ),
        GoRoute(
          path: 'purchase-orders/create',
          builder: (context, state) => const CreatePurchaseOrderPage(),
        ),
        GoRoute(
          path: 'stocktake',
          builder: (context, state) => const StocktakePage(),
        ),
        GoRoute(
          path: 'dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'eod',
          builder: (context, state) => const EndOfDayReportPage(),
        ),
        GoRoute(
          path: 'stores',
          builder: (context, state) => const StoreManagementPage(),
        ),
        GoRoute(
          path: 'audit-log',
          builder: (context, state) => const AuditLogPage(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const IngredientManagementPage(),
        ),
        GoRoute(
          path: 'analytics',
          builder: (context, state) => const AnalyticsPage(),
        ),
        GoRoute(
          path: 'kds',
          builder: (context, state) => KitchenDisplayPage(
            initialStationId: state.uri.queryParameters['station'],
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb) {
    setPathUrlStrategy();
  }
  PluginRegistry.registerDefaults();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (ctx) => AppModeProvider()),
        ChangeNotifierProvider(create: (ctx) => AuthService()),
        Provider<ClientCacheService>(create: (_) => ClientCacheService()),
        Provider<StoreService>(
          create: (_) => StoreService(FirebaseFirestore.instance),
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
        ChangeNotifierProvider(
          create: (_) => SyncQueueService(FirebaseFirestore.instance),
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
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp.router(
            routerConfig: _router,
            title: 'Restaurant App (POS)',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: ThemeData(
              brightness: Brightness.light,
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
              useMaterial3: true,
            ),
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              colorScheme: ColorScheme.fromSeed(
                seedColor: Colors.indigo,
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
            ),
          );
        },
      ),
    );
  }
}
