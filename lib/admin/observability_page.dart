import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../services/ops_observability_service.dart';

class ObservabilityPage extends StatefulWidget {
  const ObservabilityPage({super.key});

  @override
  State<ObservabilityPage> createState() => _ObservabilityPageState();
}

class _ObservabilityPageState extends State<ObservabilityPage> {
  final TextEditingController _searchController = TextEditingController();
  late final Set<OpsLogLevel> _activeLevels;

  @override
  void initState() {
    super.initState();
    _activeLevels = OpsLogLevel.values.toSet();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ops Observability'),
        actions: [
          IconButton(
            tooltip: 'Toggle debug overlay',
            icon: const Icon(Icons.bug_report_outlined),
            onPressed: () =>
                context.read<OpsObservabilityService>().toggleOverlay(),
          ),
        ],
      ),
      body: Consumer<OpsObservabilityService>(
        builder: (context, observability, child) {
          final counts = _levelCounts(observability.entries);
          final entries = observability.entries.where((entry) {
            final matchesLevel = _activeLevels.contains(entry.level);
            final query = _searchController.text.trim().toLowerCase();
            if (query.isEmpty) {
              return matchesLevel;
            }
            return matchesLevel &&
                _entryText(entry).toLowerCase().contains(query);
          }).toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _OverviewCard(
                  counts: counts,
                  searchController: _searchController,
                  onSearchChanged: (_) => setState(() {}),
                  onClearSearch: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  remoteLoggingEnabled: observability.remoteLoggingEnabled,
                  onRemoteLoggingChanged: (value) =>
                      observability.remoteLoggingEnabled = value,
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final level in OpsLogLevel.values)
                      ChoiceChip(
                        selected: _activeLevels.contains(level),
                        label: Text(
                          '${_labelFor(level)} (${counts[level] ?? 0})',
                        ),
                        onSelected: (selected) {
                          setState(() {
                            if (selected) {
                              _activeLevels.add(level);
                            } else if (_activeLevels.length > 1) {
                              _activeLevels.remove(level);
                            }
                          });
                        },
                        selectedColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: entries.isEmpty
                      ? const _EmptyLogState()
                      : _LogList(
                          entries: entries,
                          onCopy: (entry) => _copyEntry(context, entry),
                          colorForLevel: (level) => _colorFor(context, level),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Map<OpsLogLevel, int> _levelCounts(List<OpsLogEntry> entries) {
    final counts = {for (final level in OpsLogLevel.values) level: 0};
    for (final entry in entries) {
      counts[entry.level] = counts[entry.level]! + 1;
    }
    return counts;
  }

  Color _colorFor(BuildContext context, OpsLogLevel level) {
    final theme = Theme.of(context);
    switch (level) {
      case OpsLogLevel.debug:
        return theme.colorScheme.secondary;
      case OpsLogLevel.info:
        return theme.colorScheme.primary;
      case OpsLogLevel.warning:
        return Colors.orange;
      case OpsLogLevel.error:
        return theme.colorScheme.error;
    }
  }

  String _labelFor(OpsLogLevel level) {
    switch (level) {
      case OpsLogLevel.debug:
        return 'Debug';
      case OpsLogLevel.info:
        return 'Info';
      case OpsLogLevel.warning:
        return 'Warning';
      case OpsLogLevel.error:
        return 'Error';
    }
  }

  void _copyEntry(BuildContext context, OpsLogEntry entry) {
    final text = _entryText(entry);
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Log entry copied to clipboard')),
    );
  }

  String _entryText(OpsLogEntry entry) {
    final buffer = StringBuffer()
      ..writeln('[${entry.level.name.toUpperCase()}] ${entry.timestamp}')
      ..writeln(entry.message);
    if (entry.error != null) {
      buffer.writeln('Error: ${entry.error}');
    }
    if (entry.context != null) {
      buffer.writeln('Context: ${jsonEncode(entry.context)}');
    }
    if (entry.stackTrace != null) {
      buffer.writeln(entry.stackTrace);
    }
    return buffer.toString();
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.counts,
    required this.searchController,
    required this.onSearchChanged,
    required this.onClearSearch,
    required this.remoteLoggingEnabled,
    required this.onRemoteLoggingChanged,
  });

  final Map<OpsLogLevel, int> counts;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onClearSearch;
  final bool remoteLoggingEnabled;
  final ValueChanged<bool> onRemoteLoggingChanged;

  @override
  Widget build(BuildContext context) {
    final total = counts.values.fold<int>(0, (sum, value) => sum + value);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Live log stream',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('Total: $total entries'),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: searchController,
                    decoration: InputDecoration(
                      labelText: 'Search logs',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: searchController.text.isEmpty
                          ? null
                          : IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: onClearSearch,
                            ),
                    ),
                    onChanged: onSearchChanged,
                  ),
                ),
                const SizedBox(width: 16),
                Switch.adaptive(
                  value: remoteLoggingEnabled,
                  onChanged: onRemoteLoggingChanged,
                ),
                const SizedBox(width: 8),
                const Text('Remote logging'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({
    required this.entries,
    required this.onCopy,
    required this.colorForLevel,
  });

  final List<OpsLogEntry> entries;
  final ValueChanged<OpsLogEntry> onCopy;
  final Color Function(OpsLogLevel) colorForLevel;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        final color = colorForLevel(entry.level);
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '[${entry.level.name.toUpperCase()}] '
                        '${entry.timestamp.toIso8601String()}',
                        style: Theme.of(context)
                            .textTheme
                            .labelMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy),
                      tooltip: 'Copy entry',
                      onPressed: () => onCopy(entry),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(entry.message),
                if (entry.error != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    entry.error!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                if (entry.context != null) ...[
                  const SizedBox(height: 8),
                  _ContextViewer(contextMap: entry.context!),
                ],
                if (entry.stackTrace != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceVariant,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      entry.stackTrace!,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(fontFamily: 'monospace'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ContextViewer extends StatelessWidget {
  const _ContextViewer({required this.contextMap});

  final Map<String, dynamic> contextMap;

  @override
  Widget build(BuildContext context) {
    final encoder = const JsonEncoder.withIndent('  ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Context',
            style: Theme.of(context)
                .textTheme
                .labelMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            encoder.convert(contextMap),
            style:
                Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'monospace'),
          ),
        ],
      ),
    );
  }
}

class _EmptyLogState extends StatelessWidget {
  const _EmptyLogState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.event_note_outlined, size: 56),
          SizedBox(height: 12),
          Text('No log entries match the current filters.'),
        ],
      ),
    );
  }
}
