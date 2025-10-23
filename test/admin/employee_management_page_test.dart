import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:restaurant_app_final/admin/employee_management_page.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
  });

  testWidgets('EmployeeManagementPage builds correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeManagementPage(firestore: fakeFirestore),
      ),
    );

    expect(find.byType(EmployeeManagementPage), findsOneWidget);
  });

  testWidgets('Can add a new employee', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeManagementPage(firestore: fakeFirestore),
      ),
    );

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'John Doe');
    await tester.enterText(find.widgetWithText(TextFormField, '4-Digit PIN'), '1234');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final snapshot = await fakeFirestore.collection('employees').get();
    expect(snapshot.docs.length, 1);
    expect(snapshot.docs.first['name'], 'John Doe');
  });

  testWidgets('Can edit an existing employee', (WidgetTester tester) async {
    final docRef = await fakeFirestore.collection('employees').add({
      'name': 'Jane Doe',
      'role': 'Manager',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeManagementPage(firestore: fakeFirestore),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.edit));
    await tester.pumpAndSettle();

    await tester.enterText(find.widgetWithText(TextFormField, 'Name'), 'Jane Smith');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final snapshot = await fakeFirestore.collection('employees').doc(docRef.id).get();
    expect(snapshot['name'], 'Jane Smith');
  });

  testWidgets('Can delete an employee', (WidgetTester tester) async {
    final docRef = await fakeFirestore.collection('employees').add({
      'name': 'Bob Brown',
      'role': 'Intern',
    });

    await tester.pumpWidget(
      MaterialApp(
        home: EmployeeManagementPage(firestore: fakeFirestore),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.delete));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    final snapshot = await fakeFirestore.collection('employees').doc(docRef.id).get();
    expect(snapshot.exists, isFalse);
  });
}
