import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class QaPlaybooksPage extends StatefulWidget {
  const QaPlaybooksPage({super.key});

  @override
  State<QaPlaybooksPage> createState() => _QaPlaybooksPageState();
}

class _QaPlaybooksPageState extends State<QaPlaybooksPage> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  QaPlaybook? _focusedPlaybook;

  String get _searchQuery => _searchController.text.trim().toLowerCase();

  @override
  void initState() {
    super.initState();
    _focusedPlaybook = _playbooks.first;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Iterable<String> get _allTags {
    final tags = {for (final playbook in _playbooks) ...playbook.allTags};
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<QaPlaybook> get _filteredPlaybooks {
    return _playbooks.where((playbook) {
      final matchesQuery =
          _searchQuery.isEmpty || playbook.matchesQuery(_searchQuery);
      final matchesTags =
          _selectedTags.isEmpty ||
          _selectedTags.every(playbook.allTags.contains);
      return matchesQuery && matchesTags;
    }).toList();
  }

  void _toggleTag(String tag, bool selected) {
    setState(() {
      if (selected) {
        _selectedTags.add(tag);
      } else {
        _selectedTags.remove(tag);
      }
    });
  }

  void _focusPlaybook(QaPlaybook playbook) {
    setState(() {
      _focusedPlaybook = playbook;
    });
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredPlaybooks;
    final focused = filtered.contains(_focusedPlaybook)
        ? _focusedPlaybook
        : (filtered.isNotEmpty ? filtered.first : null);

    return Scaffold(
      appBar: AppBar(title: const Text('QA Playbooks')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth > 900;

          final sidebar = _PlaybookSidebar(
            controller: _searchController,
            selectedTags: _selectedTags,
            tags: _allTags,
            playbooks: filtered,
            onSearchChanged: (_) => setState(() {}),
            onTagToggled: _toggleTag,
            onSelect: _focusPlaybook,
            focused: focused,
            isExpanded: isWide,
          );

          final detail = focused == null
              ? const _EmptyState()
              : _PlaybookDetail(playbook: focused);

          if (!isWide) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [sidebar, const SizedBox(height: 16), detail],
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(width: 360, child: sidebar),
                const SizedBox(width: 24),
                Expanded(child: detail),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PlaybookSidebar extends StatelessWidget {
  const _PlaybookSidebar({
    super.key,
    required this.controller,
    required this.tags,
    required this.selectedTags,
    required this.playbooks,
    required this.onSearchChanged,
    required this.onTagToggled,
    required this.onSelect,
    required this.focused,
    this.isExpanded = false,
  });

  final TextEditingController controller;
  final Iterable<String> tags;
  final Set<String> selectedTags;
  final List<QaPlaybook> playbooks;
  final ValueChanged<String> onSearchChanged;
  final void Function(String tag, bool selected) onTagToggled;
  final ValueChanged<QaPlaybook> onSelect;
  final QaPlaybook? focused;
  final bool isExpanded;

  @override
  Widget build(BuildContext context) {
    final list = playbooks.isEmpty
        ? const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No playbooks match the current filters.'),
            ),
          )
        : ListView.separated(
            shrinkWrap: !isExpanded,
            physics: isExpanded ? null : const NeverScrollableScrollPhysics(),
            itemCount: playbooks.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final playbook = playbooks[index];
              final isSelected = playbook == focused;
              return ListTile(
                selected: isSelected,
                selectedTileColor: Theme.of(
                  context,
                ).colorScheme.primaryContainer,
                title: Text(playbook.title),
                subtitle: Text(playbook.summary),
                onTap: () => onSelect(playbook),
                trailing: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      playbook.owner,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    if (playbook.lastUpdated != null)
                      Text(
                        DateFormat.yMMMd().format(playbook.lastUpdated!),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                  ],
                ),
              );
            },
          );

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: controller,
                  decoration: InputDecoration(
                    labelText: 'Search playbooks',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: controller.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              controller.clear();
                              onSearchChanged('');
                            },
                          ),
                  ),
                  onChanged: onSearchChanged,
                ),
                const SizedBox(height: 16),
                if (tags.isNotEmpty) ...[
                  const Text(
                    'Filter by tag',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tag in tags)
                        FilterChip(
                          label: Text(tag),
                          selected: selectedTags.contains(tag),
                          onSelected: (value) => onTagToggled(tag, value),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          ),
          const Divider(height: 1),
          if (isExpanded) Expanded(child: list) else list,
        ],
      ),
    );
  }
}

class _PlaybookDetail extends StatefulWidget {
  const _PlaybookDetail({super.key, required this.playbook});

  final QaPlaybook playbook;

  @override
  State<_PlaybookDetail> createState() => _PlaybookDetailState();
}

class _PlaybookDetailState extends State<_PlaybookDetail> {
  late PlaybookRevision _selectedRevision;

  @override
  void initState() {
    super.initState();
    _selectedRevision = widget.playbook.latestRevision;
  }

  @override
  void didUpdateWidget(covariant _PlaybookDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.playbook != widget.playbook) {
      _selectedRevision = widget.playbook.latestRevision;
    } else if (!widget.playbook.revisions.contains(_selectedRevision)) {
      _selectedRevision = widget.playbook.latestRevision;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final revision = _selectedRevision;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.playbook.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Text('Revision:', style: theme.textTheme.titleSmall),
                  const SizedBox(width: 12),
                  DropdownButton<PlaybookRevision>(
                    key: const Key('revisionDropdown'),
                    value: revision,
                    items: [
                      for (final rev in widget.playbook.revisions)
                        DropdownMenuItem<PlaybookRevision>(
                          value: rev,
                          child: Text(rev.id),
                        ),
                    ],
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _selectedRevision = value;
                      });
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(revision.summary, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 8),
              if (revision.changeSummary.isNotEmpty)
                Text(
                  'Change summary: ${revision.changeSummary}',
                  style: theme.textTheme.bodyMedium,
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.manage_accounts, size: 18),
                    label: Text('Owner: ${widget.playbook.owner}'),
                  ),
                  if (revision.updatedAt != null)
                    Chip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(
                        'Updated ${DateFormat.yMMMd().format(revision.updatedAt!)}',
                      ),
                    ),
                  if (revision.targetResolution != null)
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(
                        'Resolve in ${revision.targetResolution!.inMinutes} mins',
                      ),
                    ),
                  for (final tag in widget.playbook.allTags)
                    Chip(
                      avatar: const Icon(Icons.sell_outlined, size: 18),
                      label: Text(tag),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              _SectionHeader('Trigger & Detection'),
              _BulletList(items: revision.triggers),
              const SizedBox(height: 16),
              _SectionHeader('Checklist'),
              _NumberedList(items: revision.steps),
              if (revision.signals.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader('Success Signals'),
                _BulletList(items: revision.signals),
              ],
              if (revision.followUp.isNotEmpty) ...[
                const SizedBox(height: 16),
                _SectionHeader('Follow-up Actions'),
                _BulletList(items: revision.followUp),
              ],
              const SizedBox(height: 24),
              if (revision.resources.isNotEmpty) ...[
                _SectionHeader('Reference Resources'),
                _BulletList(items: revision.resources),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: const [
            Icon(Icons.fact_check_outlined, size: 56),
            SizedBox(height: 16),
            Text('Select a playbook to see the details.'),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SelectableText(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('• '),
                Expanded(child: Text(item)),
              ],
            ),
          ),
      ],
    );
  }
}

class _NumberedList extends StatelessWidget {
  const _NumberedList({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${i + 1}. '),
                Expanded(child: Text(items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class PlaybookRevision {
  const PlaybookRevision({
    required this.id,
    required this.summary,
    this.changeSummary = '',
    this.updatedAt,
    this.targetResolution,
    this.triggers = const <String>[],
    this.steps = const <String>[],
    this.signals = const <String>[],
    this.followUp = const <String>[],
    this.resources = const <String>[],
  });

  final String id;
  final String summary;
  final String changeSummary;
  final DateTime? updatedAt;
  final Duration? targetResolution;
  final List<String> triggers;
  final List<String> steps;
  final List<String> signals;
  final List<String> followUp;
  final List<String> resources;
}

const Map<String, List<String>> _tagKeywordMap = {
  'payments': ['payment', 'card reader', 'terminal', 'pos', 'cashier'],
  'hardware': ['reader', 'device', 'tablet', 'router', 'hardware'],
  'critical': ['offline', 'escalate', 'cash-only', 'outage'],
  'kitchen': ['kitchen', 'kds'],
  'performance': ['stall', 'lag', 'delay', 'freeze', 'slow'],
  'menu': ['menu'],
  'release': ['publish', 'release'],
  'regression': ['regression'],
  'reporting': ['reporting', 'reports'],
  'data': ['export', 'bigquery', 'dataset', 'csv'],
  'finance': ['finance', 'accounting'],
};

Set<String> generateTags({
  required String title,
  required Iterable<PlaybookRevision> revisions,
}) {
  final searchableText = <String>{
    title,
    for (final revision in revisions) ...[
      ...revision.triggers,
      ...revision.steps,
      ...revision.followUp,
    ],
  }.map((value) => value.toLowerCase()).join(' ');

  final tags = <String>{};
  for (final entry in _tagKeywordMap.entries) {
    if (entry.value
        .map((keyword) => keyword.toLowerCase())
        .any(searchableText.contains)) {
      tags.add(entry.key);
    }
  }
  return tags;
}

class QaPlaybook {
  QaPlaybook({
    required this.title,
    required this.owner,
    List<String> tags = const <String>[],
    required this.revisions,
  }) : _manualTags = List.unmodifiable(tags),
       assert(revisions.isNotEmpty, 'QaPlaybook must have at least 1 revision');

  final String title;
  final String owner;
  final List<PlaybookRevision> revisions;
  final List<String> _manualTags;

  late final List<String> allTags = _computeAllTags();

  List<String> get tags => _manualTags;

  PlaybookRevision get latestRevision {
    return revisions.reduce((value, element) {
      final valueDate = value.updatedAt;
      final elementDate = element.updatedAt;
      if (valueDate == null && elementDate == null) {
        return value;
      }
      if (valueDate == null) {
        return element;
      }
      if (elementDate == null) {
        return value;
      }
      return valueDate.isAfter(elementDate) ? value : element;
    });
  }

  String get summary => latestRevision.summary;
  DateTime? get lastUpdated => latestRevision.updatedAt;
  Duration? get targetResolution => latestRevision.targetResolution;
  List<String> get triggers => latestRevision.triggers;
  List<String> get steps => latestRevision.steps;
  List<String> get signals => latestRevision.signals;
  List<String> get followUp => latestRevision.followUp;
  List<String> get resources => latestRevision.resources;

  bool matchesQuery(String query) {
    final revisionText = revisions
        .expand(
          (revision) => [
            revision.id,
            revision.summary,
            revision.changeSummary,
            ...revision.triggers,
            ...revision.steps,
            ...revision.signals,
            ...revision.followUp,
            ...revision.resources,
          ],
        )
        .join(' ')
        .toLowerCase();

    final haystack = [
      title,
      owner,
      ...allTags,
      revisionText,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }

  List<String> _computeAllTags() {
    final generated = generateTags(title: title, revisions: revisions);
    final manual = _manualTags
        .map((tag) => tag.toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet();
    final combined = <String>{...generated, ...manual}.toList()..sort();
    return combined;
  }
}

final List<QaPlaybook> _playbooks = [
  QaPlaybook(
    title: 'Payments: Card Reader Offline',
    owner: 'Ops Guild',
    revisions: [
      PlaybookRevision(
        id: 'v1.2.0',
        summary:
            'Investigate when the payment terminal cannot reach the gateway.',
        changeSummary:
            'Clarified escalation path and added cash-only fallback guidance.',
        updatedAt: DateTime(2024, 3, 12),
        targetResolution: Duration(minutes: 30),
        triggers: const [
          'Cashiers report repeated payment failures with status OFFLINE.',
          'Observability dashboard shows spikes in payment retries.',
        ],
        steps: const [
          'Confirm that the payment gateway status page reports an incident.',
          'Check the in-store internet connection and restart the router if needed.',
          'Power-cycle the card reader and verify it reconnects to Wi-Fi.',
          'If the issue persists, switch the store to cash-only mode and escalate to L2.',
        ],
        signals: const [
          'Successful test transaction processed after restart.',
          'No new errors in payment gateway logs for 10 minutes.',
        ],
        followUp: const [
          'Log incident summary in QA channel.',
          'Schedule preventative maintenance if device is older than 18 months.',
        ],
        resources: const [
          'https://status.stripe.com',
          'Internal guide: POS network hardening checklist',
        ],
      ),
      PlaybookRevision(
        id: 'v1.0.0',
        summary: 'Legacy workflow for mitigating offline card readers.',
        changeSummary:
            'Original draft with emphasis on vendor support confirmation.',
        updatedAt: DateTime(2023, 9, 10),
        targetResolution: Duration(minutes: 35),
        triggers: const [
          'Store manager reports terminal stuck in reconnecting state.',
          'Support hotline receives multiple offline terminal alerts.',
        ],
        steps: const [
          'Verify power and network cabling for the reader.',
          'Restart the router and wait 5 minutes for devices to recover.',
          'Contact vendor support to confirm if there is a regional outage.',
          'Document incident status in the ops log and monitor for 30 minutes.',
        ],
        signals: const ['Reader successfully processes a \$1 authorization.'],
        followUp: const [
          'Update incident ticket with vendor reference number.',
        ],
        resources: const ['Vendor hotline: +1-800-555-0133'],
      ),
    ],
  ),
  QaPlaybook(
    title: 'Kitchen Display Queue Stalling',
    owner: 'Engineering',
    revisions: [
      PlaybookRevision(
        id: 'v2.1.0',
        summary: 'Orders stop updating on KDS screens during peak service.',
        changeSummary:
            'Added rebuild instructions for sync queue and metrics to watch.',
        updatedAt: DateTime(2024, 1, 28),
        targetResolution: Duration(minutes: 20),
        triggers: const [
          'Tickets remain in Preparing state for more than 15 minutes.',
          'Kitchen staff report missing chimes on new orders.',
        ],
        steps: const [
          'Open Observability > Sync Queue to ensure background workers are healthy.',
          'Restart the affected KDS tablet and confirm it re-syncs.',
          'Rebuild the sync queue from admin > Maintenance tools.',
          'Escalate to platform team if backlog exceeds 50 pending jobs.',
        ],
        signals: const [
          'Average ticket time drops below 6 minutes.',
          'No pending jobs remain in the sync queue.',
        ],
        followUp: const [
          'Capture HAR log from the device if problem recurs.',
          'File retrospective issue with timestamps and affected stores.',
        ],
        resources: const [
          'Runbook: Sync service health checks',
          'Device SOP: Tablet reboot and cache clear',
        ],
      ),
      PlaybookRevision(
        id: 'v1.3.0',
        summary:
            'Baseline steps for when kitchen displays lag or freeze updates.',
        changeSummary: 'Documented temporary fix via kiosk service restart.',
        updatedAt: DateTime(2023, 6, 5),
        targetResolution: Duration(minutes: 25),
        triggers: const [
          'Orders take longer than 10 minutes to appear on displays.',
        ],
        steps: const [
          'Check kiosk service status in admin console.',
          'Restart kiosk service for the impacted location.',
          'Verify new orders flow in within 3 minutes.',
        ],
        signals: const ['Kiosk service uptime indicator returns to green.'],
        followUp: const ['Email engineering on-call with incident summary.'],
        resources: const ['Internal doc: KDS networking primer'],
      ),
    ],
  ),
  QaPlaybook(
    title: 'Menu Publishing Regression',
    owner: 'Menu QA',
    revisions: [
      PlaybookRevision(
        id: 'v3.0.0',
        summary: 'New menu items are not visible in customer channels.',
        changeSummary:
            'Updated diff tooling instructions and clarified escalation.',
        updatedAt: DateTime(2024, 4, 2),
        targetResolution: Duration(minutes: 45),
        triggers: const [
          'Staging publish succeeded but production channels show stale menu.',
          'Retail POS receives a schema mismatch warning.',
        ],
        steps: const [
          'Verify the menu publish job status in Cloud Tasks and Firestore.',
          'Run menu diff tool against the affected tenant.',
          'Trigger a manual re-publish from the admin portal.',
          'Contact release manager if data mismatch persists.',
        ],
        signals: const [
          'Menu diff returns zero discrepancies.',
          'Customer app loads updated items without errors.',
        ],
        followUp: const [
          'Tag release commit with "needs-backport" if hotfix required.',
          'Update regression test suite with new coverage gaps.',
        ],
        resources: const [
          'Docs: Menu publishing pipeline overview',
          'QA Tooling: Tenant diff CLI usage',
        ],
      ),
      PlaybookRevision(
        id: 'v2.2.1',
        summary: 'Checklist prior to manual publish reruns.',
        changeSummary: 'Added step to verify CDN purge completion.',
        updatedAt: DateTime(2023, 12, 18),
        targetResolution: Duration(minutes: 40),
        triggers: const [
          'Merchants report missing new menu items after publish.',
        ],
        steps: const [
          'Confirm publish queue job completed successfully.',
          'Purge CDN cache for the tenant.',
          'Re-run publish workflow with verbose logging enabled.',
        ],
        signals: const ['CDN invalidation completes within 5 minutes.'],
        followUp: const ['Notify release manager of manual intervention.'],
        resources: const ['CDN purge instructions'],
      ),
    ],
  ),
  QaPlaybook(
    title: 'Data Export Delays',
    owner: 'Finance Ops',
    tags: const ['ops'],
    revisions: [
      PlaybookRevision(
        id: 'v1.5.0',
        summary: 'Scheduled exports to accounting systems are lagging behind.',
        changeSummary:
            'Refined retry process and added incremental export guidance.',
        updatedAt: DateTime(2023, 11, 16),
        targetResolution: Duration(hours: 2),
        triggers: const [
          'Accounting team reports missing files after 2 AM schedule.',
          'BigQuery export queue shows retrying jobs.',
        ],
        steps: const [
          'Check Cloud Scheduler execution logs for recent failures.',
          'Confirm service account credentials are still valid.',
          'Manually trigger the export function and monitor progress.',
          'If backlogged, notify stakeholders and queue incremental export.',
        ],
        signals: const [
          'Latest export files available in shared drive.',
          'Scheduler dashboard returns to green status.',
        ],
        followUp: const [
          'Document incident in finance operations tracker.',
          'Review alert thresholds for export latency.',
        ],
        resources: const [
          'Runbook: BigQuery export troubleshooting',
          'Finance SOP: Data integrity verification',
        ],
      ),
      PlaybookRevision(
        id: 'v1.2.0',
        summary: 'Early playbook for delayed data exports.',
        changeSummary: 'Established process for temporary manual exports.',
        updatedAt: DateTime(2023, 5, 9),
        targetResolution: Duration(hours: 3),
        triggers: const ['Scheduled export misses agreed delivery window.'],
        steps: const [
          'Verify export job status in monitoring dashboard.',
          'Notify stakeholders of anticipated delay.',
          'Kick off manual export script from operations toolkit.',
        ],
        signals: const ['Manual export file delivered to stakeholders.'],
        followUp: const ['Review monitoring alerts for missed warning signs.'],
        resources: const ['Operations toolkit manual export guide'],
      ),
    ],
  ),
];
