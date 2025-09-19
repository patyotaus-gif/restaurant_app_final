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
          path: 'dashboard',
          builder: (context, state) => const DashboardPage(),
        ),
        GoRoute(
          path: 'eod',
          builder: (context, state) => const EndOfDayReportPage(),
        ),
        GoRoute(
          path: 'inventory',
          builder: (context, state) => const IngredientManagementPage(),
        ),
        GoRoute(
          path: 'kds',
          builder: (context, state) => const KitchenDisplayPage(),
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
        ChangeNotifierProvider(create: (ctx) => ThemeProvider()),
        ChangeNotifierProvider(create: (ctx) => StockProvider()),
        ChangeNotifierProvider(
          create: (_) => SyncQueueService(FirebaseFirestore.instance),
        ),
        Provider<NotificationsRepository>(
          create: (_) => NotificationsRepository(FirebaseFirestore.instance),
        ),
        ChangeNotifierProxyProvider<StockProvider, CartProvider>(
          create: (ctx) => CartProvider(),
          update: (ctx, stock, previousCart) {
            previousCart?.update(stock);
            return previousCart ?? CartProvider();
          },
        ),
        ChangeNotifierProxyProvider<AuthService, NotificationProvider>(
          create: (ctx) {
            final repo = ctx.read<NotificationsRepository>();
            return NotificationProvider(repo: repo, uid: 'anonymous');
          },
          update: (ctx, auth, previousProvider) {
            final repo = ctx.read<NotificationsRepository>();
            final uid = auth.loggedInEmployee?.id ?? 'anonymous';
            previousProvider?.updateUid(uid);
            return previousProvider ??
                NotificationProvider(repo: repo, uid: uid);
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
