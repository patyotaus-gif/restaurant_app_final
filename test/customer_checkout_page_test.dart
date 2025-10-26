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
    final firestore = _InMemoryFirebaseFirestore();
    final syncQueue = SyncQueueService(
      firestore,
      connectivity: connectivity,
    );
    final defaultOnError = FlutterError.onError;

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

class _InMemoryFirebaseFirestore extends Fake implements FirebaseFirestore {
  final Map<String, _InMemoryCollectionReference> _collections = {};

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) {
    return _collections.putIfAbsent(
      path,
      () => _InMemoryCollectionReference(path),
    );
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryCollectionReference extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  _InMemoryCollectionReference(this._path);

  final String _path;
  final List<_InMemoryDocumentReference> _documents = [];

  @override
  Future<DocumentReference<Map<String, dynamic>>> add(
    Map<String, dynamic> data,
  ) async {
    final document = _InMemoryDocumentReference(
      _path,
      Map<String, dynamic>.from(data),
    );
    _documents.add(document);
    return document;
  }

  @override
  String get path => _path;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _InMemoryDocumentReference extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  _InMemoryDocumentReference(
    this._collectionPath,
    Map<String, dynamic> data,
  )   : _data = data,
        id = _generateDocumentId();

  final String _collectionPath;
  final Map<String, dynamic> _data;

  @override
  final String id;

  @override
  String get path => '$_collectionPath/$id';

  Map<String, dynamic> get data => _data;

  static String _generateDocumentId() {
    final random = Random();
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(20, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
