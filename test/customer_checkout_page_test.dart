import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_app_final/cart_provider.dart';
import 'package:restaurant_app_final/customer_checkout_page.dart';
import 'package:restaurant_app_final/services/sync_queue_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeConnectivity extends Fake implements Connectivity {
  final _controller = StreamController<List<ConnectivityResult>>.broadcast();

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async {
    return [ConnectivityResult.wifi];
  }

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      _controller.stream;

  void dispose() {
    unawaited(_controller.close());
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('confirm payment while online completes without build errors', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});

    final connectivity = _FakeConnectivity();
    inal firestore = FakeFirebaseFirestore();
    final syncQueue = SyncQueueService(
      firestore: firestore,
      connectivity: connectivity,
    );

    addTearDown(() {
      FlutterError.onError = defaultOnError;
      connectivity.dispose();
      syncQueue.dispose();
    });

    final product = Product(
      id: 'p1',
      name: 'Pad Thai',
      price: 120.0,
      category: 'Main',
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<SyncQueueService>.value(
        value: syncQueue,
        child: MaterialApp(
          home: CustomerCheckoutPage(
            tableNumber: 'A1',
            cart: {'p1': CartItem(product: product)},
            totalAmount: 120.0,
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.runAsync(() async {
      await tester.tap(find.text('I HAVE PAID - CONFIRM'));
      await tester.pumpAndSettle();
    });

    final exception = tester.takeException();
    expect(exception, isNull);

    expect(find.text('Payment Confirmed!'), findsOneWidget);
  });
}
