import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app_final/admin/analytics_page.dart';

void main() {
  late FakeFirebaseFirestore firestore;

  setUp(() {
    firestore = FakeFirebaseFirestore();
  });

  Future<void> _addExportJob(DateTime requestedAt) async {
    await firestore.collection('analytics_exports').add({
      'requestedAt': Timestamp.fromDate(requestedAt),
      'status': 'completed',
      'table': 'orders',
      'rangeStart': Timestamp.fromDate(requestedAt.subtract(const Duration(days: 1))),
      'rangeEnd': Timestamp.fromDate(requestedAt),
    });
  }

  testWidgets('AnalyticsPage only shows recent export jobs', (WidgetTester tester) async {
    // Add a recent export job
    await _addExportJob(DateTime.now().subtract(const Duration(days: 15)));
    // Add an old export job
    await _addExportJob(DateTime.now().subtract(const Duration(days: 45)));

    await tester.pumpWidget(
      MaterialApp(
        home: AnalyticsPage(),
      ),
    );

    await tester.pumpAndSettle();

    // Check that only the recent export job is displayed
    expect(find.text('orders • COMPLETED'), findsOneWidget);
  });
}
