import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app_final/admin/qa_playbooks_page.dart';

void main() {
  testWidgets('Selecting older revision updates checklist and metadata',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: QaPlaybooksPage()));
    await tester.pumpAndSettle();

    expect(find.text('Updated Mar 12, 2024'), findsOneWidget);
    expect(
      find.textContaining('Power-cycle the card reader'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('revisionDropdown')));
    await tester.pumpAndSettle();

    await tester.tap(find.text('v1.0.0').last);
    await tester.pumpAndSettle();

    expect(find.text('Updated Sep 10, 2023'), findsOneWidget);
    expect(
      find.textContaining('Contact vendor support to confirm if there is a regional outage.'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Power-cycle the card reader'),
      findsNothing,
    );
    expect(
      find.textContaining('Original draft with emphasis on vendor support confirmation.'),
      findsOneWidget,
    );
  });
}
