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
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QaPlaybooksPage(),
        ),
      ),
    );
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Updated') ?? false),
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining('Power-cycle the card reader'),
      findsOneWidget,
    );

    await tester.tap(find.byKey(const Key('revisionDropdown')));
    await tester.pump();

    await tester.tap(find.text('v1.0.0').last);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && (widget.data?.startsWith('Updated') ?? false),
      ),
      findsOneWidget,
    );
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
    await tester.pump();

    final paymentsChip = find.widgetWithText(FilterChip, 'payments');
    expect(paymentsChip, findsOneWidget);

    await tester.tap(paymentsChip);
    await tester.pump();

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ListTile &&
            widget.selected &&
            (widget.title as Text).data == 'Payments: Card Reader Offline',
      ),
      findsOneWidget,
    );
    expect(find.text('Kitchen Display Queue Stalling'), findsNothing);

    await tester.tap(paymentsChip);
    await tester.pump();

    expect(find.text('Kitchen Display Queue Stalling'), findsOneWidget);
  });
}
