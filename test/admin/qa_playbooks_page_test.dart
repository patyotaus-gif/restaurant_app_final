import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:restaurant_app_final/admin/qa_playbooks_page.dart';

void main() {
  test('QaPlaybook generates tags from playbook content', () {
    final playbook = QaPlaybook(
      title: 'Payments Terminal Offline',
      owner: 'Ops Guild',
      tags: const ['priority'],
      revisions: const [
        PlaybookRevision(
          id: 'v1',
          summary: 'Terminal outage scenario',
          triggers: [
            'Cashiers report repeated payment failures with status OFFLINE.',
          ],
          steps: [
            'Power-cycle the card reader and verify it reconnects to Wi-Fi.',
          ],
          followUp: [
            'Escalate to network engineering if the reader does not recover.',
          ],
        ),
      ],
    );

    expect(
      playbook.allTags,
      containsAll(<String>['critical', 'hardware', 'payments', 'priority']),
    );
  });

  testWidgets('Selecting older revision updates checklist and metadata',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: QaPlaybooksPage(),
          ),
        ),
      ),
    );
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

  testWidgets('Tag filtering works with automatically generated tags',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 800,
            child: QaPlaybooksPage(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final paymentsChip = find.widgetWithText(FilterChip, 'payments');
    expect(paymentsChip, findsOneWidget);

    await tester.tap(paymentsChip);
    await tester.pumpAndSettle();

    expect(find.text('Payments: Card Reader Offline'), findsOneWidget);
    expect(find.text('Kitchen Display Queue Stalling'), findsNothing);

    await tester.tap(paymentsChip);
    await tester.pumpAndSettle();

    expect(find.text('Kitchen Display Queue Stalling'), findsOneWidget);
  });
}
