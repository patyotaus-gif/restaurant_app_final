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
    final tags = {
      for (final playbook in _playbooks) ...playbook.tags,
    };
    final sorted = tags.toList()..sort();
    return sorted;
  }

  List<QaPlaybook> get _filteredPlaybooks {
    return _playbooks.where((playbook) {
      final matchesQuery =
          _searchQuery.isEmpty || playbook.matchesQuery(_searchQuery);
      final matchesTags = _selectedTags.isEmpty ||
          _selectedTags.every(playbook.tags.contains);
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
      appBar: AppBar(
        title: const Text('QA Playbooks'),
      ),
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
          );

          final detail = focused == null
              ? const _EmptyState()
              : _PlaybookDetail(playbook: focused);

          if (!isWide) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                sidebar,
                const SizedBox(height: 16),
                detail,
              ],
            );
          }

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 360,
                  child: sidebar,
                ),
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
    required this.controller,
    required this.tags,
    required this.selectedTags,
    required this.playbooks,
    required this.onSearchChanged,
    required this.onTagToggled,
    required this.onSelect,
    required this.focused,
  });

  final TextEditingController controller;
  final Iterable<String> tags;
  final Set<String> selectedTags;
  final List<QaPlaybook> playbooks;
  final ValueChanged<String> onSearchChanged;
  final void Function(String tag, bool selected) onTagToggled;
  final ValueChanged<QaPlaybook> onSelect;
  final QaPlaybook? focused;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: playbooks.isEmpty
                ? const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No playbooks match the current filters.'),
                    ),
                  )
                : ListView.separated(
                    itemCount: playbooks.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final playbook = playbooks[index];
                      final isSelected = playbook == focused;
                      return ListTile(
                        selected: isSelected,
                        selectedTileColor:
                            Theme.of(context).colorScheme.primaryContainer,
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
                                DateFormat.yMMMd()
                                    .format(playbook.lastUpdated!),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PlaybookDetail extends StatelessWidget {
  const _PlaybookDetail({required this.playbook});

  final QaPlaybook playbook;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                playbook.title,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(playbook.summary),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.manage_accounts, size: 18),
                    label: Text('Owner: ${playbook.owner}'),
                  ),
                  if (playbook.lastUpdated != null)
                    Chip(
                      avatar: const Icon(Icons.history, size: 18),
                      label: Text(
                        'Updated ${DateFormat.yMMMd().format(playbook.lastUpdated!)}',
                      ),
                    ),
                  if (playbook.targetResolution != null)
                    Chip(
                      avatar: const Icon(Icons.timer_outlined, size: 18),
                      label: Text(
                        'Resolve in ${playbook.targetResolution!.inMinutes} mins',
                      ),
                    ),
                  for (final tag in playbook.tags)
                    Chip(
                      avatar: const Icon(Icons.sell_outlined, size: 18),
                      label: Text(tag),
                    ),
                ],
              ),
              const SizedBox(height: 24),
              const _SectionHeader('Trigger & Detection'),
              _BulletList(items: playbook.triggers),
              const SizedBox(height: 16),
              const _SectionHeader('Checklist'),
              _NumberedList(items: playbook.steps),
              if (playbook.signals.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionHeader('Success Signals'),
                _BulletList(items: playbook.signals),
              ],
              if (playbook.followUp.isNotEmpty) ...[
                const SizedBox(height: 16),
                const _SectionHeader('Follow-up Actions'),
                _BulletList(items: playbook.followUp),
              ],
              const SizedBox(height: 24),
              if (playbook.resources.isNotEmpty) ...[
                const _SectionHeader('Reference Resources'),
                _BulletList(items: playbook.resources),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

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
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.items});

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
  const _NumberedList({required this.items});

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

class QaPlaybook {
  const QaPlaybook({
    required this.title,
    required this.summary,
    required this.owner,
    this.lastUpdated,
    this.targetResolution,
    this.tags = const <String>[],
    this.triggers = const <String>[],
    this.steps = const <String>[],
    this.signals = const <String>[],
    this.followUp = const <String>[],
    this.resources = const <String>[],
  });

  final String title;
  final String summary;
  final String owner;
  final DateTime? lastUpdated;
  final Duration? targetResolution;
  final List<String> tags;
  final List<String> triggers;
  final List<String> steps;
  final List<String> signals;
  final List<String> followUp;
  final List<String> resources;

  bool matchesQuery(String query) {
    final haystack = [
      title,
      summary,
      owner,
      ...tags,
      ...triggers,
      ...steps,
      ...signals,
      ...followUp,
      ...resources,
    ].join(' ').toLowerCase();
    return haystack.contains(query);
  }
}

const List<QaPlaybook> _playbooks = [
  QaPlaybook(
    title: 'Payments: Card Reader Offline',
    summary: 'Investigate when the payment terminal cannot reach the gateway.',
    owner: 'Ops Guild',
    tags: ['payments', 'critical', 'hardware'],
    lastUpdated: DateTime(2024, 3, 12),
    targetResolution: Duration(minutes: 30),
    triggers: [
      'Cashiers report repeated payment failures with status OFFLINE.',
      'Observability dashboard shows spikes in payment retries.',
    ],
    steps: [
      'Confirm that the payment gateway status page reports an incident.',
      'Check the in-store internet connection and restart the router if needed.',
      'Power-cycle the card reader and verify it reconnects to Wi-Fi.',
      'If the issue persists, switch the store to cash-only mode and escalate to L2.',
    ],
    signals: [
      'Successful test transaction processed after restart.',
      'No new errors in payment gateway logs for 10 minutes.',
    ],
    followUp: [
      'Log incident summary in QA channel.',
      'Schedule preventative maintenance if device is older than 18 months.',
    ],
    resources: [
      'https://status.stripe.com',
      'Internal guide: POS network hardening checklist',
    ],
  ),
  QaPlaybook(
    title: 'Kitchen Display Queue Stalling',
    summary: 'Orders stop updating on KDS screens during peak service.',
    owner: 'Engineering',
    tags: ['kitchen', 'performance'],
    lastUpdated: DateTime(2024, 1, 28),
    targetResolution: Duration(minutes: 20),
    triggers: [
      'Tickets remain in Preparing state for more than 15 minutes.',
      'Kitchen staff report missing chimes on new orders.',
    ],
    steps: [
      'Open Observability > Sync Queue to ensure background workers are healthy.',
      'Restart the affected KDS tablet and confirm it re-syncs.',
      'Rebuild the sync queue from admin > Maintenance tools.',
      'Escalate to platform team if backlog exceeds 50 pending jobs.',
    ],
    signals: [
      'Average ticket time drops below 6 minutes.',
      'No pending jobs remain in the sync queue.',
    ],
    followUp: [
      'Capture HAR log from the device if problem recurs.',
      'File retrospective issue with timestamps and affected stores.',
    ],
    resources: [
      'Runbook: Sync service health checks',
      'Device SOP: Tablet reboot and cache clear',
    ],
  ),
  QaPlaybook(
    title: 'Menu Publishing Regression',
    summary: 'New menu items are not visible in customer channels.',
    owner: 'Menu QA',
    tags: ['menu', 'release', 'regression'],
    lastUpdated: DateTime(2024, 4, 2),
    targetResolution: Duration(minutes: 45),
    triggers: [
      'Staging publish succeeded but production channels show stale menu.',
      'Retail POS receives a schema mismatch warning.',
    ],
    steps: [
      'Verify the menu publish job status in Cloud Tasks and Firestore.',
      'Run menu diff tool against the affected tenant.',
      'Trigger a manual re-publish from the admin portal.',
      'Contact release manager if data mismatch persists.',
    ],
    signals: [
      'Menu diff returns zero discrepancies.',
      'Customer app loads updated items without errors.',
    ],
    followUp: [
      'Tag release commit with "needs-backport" if hotfix required.',
      'Update regression test suite with new coverage gaps.',
    ],
    resources: [
      'Docs: Menu publishing pipeline overview',
      'QA Tooling: Tenant diff CLI usage',
    ],
  ),
  QaPlaybook(
    title: 'Data Export Delays',
    summary: 'Scheduled exports to accounting systems are lagging behind.',
    owner: 'Finance Ops',
    tags: ['reporting', 'data'],
    lastUpdated: DateTime(2023, 11, 16),
    targetResolution: Duration(hours: 2),
    triggers: [
      'Accounting team reports missing files after 2 AM schedule.',
      'BigQuery export queue shows retrying jobs.',
    ],
    steps: [
      'Check Cloud Scheduler execution logs for recent failures.',
      'Confirm service account credentials are still valid.',
      'Manually trigger the export function and monitor progress.',
      'If backlogged, notify stakeholders and queue incremental export.',
    ],
    signals: [
      'Latest export files available in shared drive.',
      'Scheduler dashboard returns to green status.',
    ],
    followUp: [
      'Document incident in finance operations tracker.',
      'Review alert thresholds for export latency.',
    ],
    resources: [
      'Runbook: BigQuery export troubleshooting',
      'Finance SOP: Data integrity verification',
    ],
  ),
];
