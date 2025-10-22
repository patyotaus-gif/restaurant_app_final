import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/analytics_service.dart';
class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  late final AnalyticsService _analyticsService;
  DateTimeRange? _selectedRange;
  bool _isExporting = false;
  bool _isCalculating = false;

  @override
  void initState() {
    super.initState();
    _analyticsService = AnalyticsService(FirebaseFirestore.instance);
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final initialRange =
        _selectedRange ??
        DateTimeRange(start: now.subtract(const Duration(days: 7)), end: now);
    final range = await showDateRangePicker(
      context: context,
      initialDateRange: initialRange,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (range != null) {
      setState(() {
        _selectedRange = range;
      });
    }
  }

  Future<void> _queueExport() async {
    if (_selectedRange == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a date range first.')),
      );
      return;
    }
    setState(() {
      _isExporting = true;
    });
    try {
      await _analyticsService.queueBigQueryExport(
        start: _selectedRange!.start,
        end: _selectedRange!.end,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export request queued successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to queue export: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _runRfmScoring() async {
    setState(() {
      _isCalculating = true;
    });
    try {
      await _analyticsService.calculateAndStoreRfmScores(
        lookback: DateTime.now().subtract(const Duration(days: 365)),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('RFM scoring complete.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to calculate RFM scores: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isCalculating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rangeLabel = _selectedRange == null
        ? 'No range selected'
        : '${_formatDate(_selectedRange!.start)} - ${_formatDate(_selectedRange!.end)}';

    return Scaffold(
      appBar: AppBar(title: const Text('Analytics & CRM')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'BigQuery Export',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(rangeLabel),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickRange,
                          icon: const Icon(Icons.calendar_today),
                          label: const Text('Select Range'),
                        ),
                        ElevatedButton.icon(
                          onPressed: _isExporting ? null : _queueExport,
                          icon: _isExporting
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.cloud_upload),
                          label: const Text('Queue Export'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Recent export jobs',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _ExportJobsList(),
                  ],
                ),
              ),
            ),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'RFM Scoring',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Recalculate customer Recency, Frequency, Monetary scores for CRM segmentation. '
                      'Uses the past 12 months of completed orders.',
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: _isCalculating ? null : _runRfmScoring,
                      icon: _isCalculating
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_graph),
                      label: const Text('Recalculate RFM Scores'),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Last run',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    _RfmJobStatus(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _ExportJobsList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final query = FirebaseFirestore.instance
        .collection('analytics_exports')
        .where('requestedAt', isGreaterThanOrEqualTo: thirtyDaysAgo)
        .orderBy('requestedAt', descending: true)
        .limit(10);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Text('No export jobs yet.');
        }
        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data();
            final Timestamp? requestedAt = data['requestedAt'] as Timestamp?;
            final Timestamp? completedAt = data['completedAt'] as Timestamp?;
            final String status = data['status'] as String? ?? 'queued';
            final String table = data['table'] as String? ?? 'orders';
            final rangeStart = data['rangeStart'] as Timestamp?;
            final rangeEnd = data['rangeEnd'] as Timestamp?;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('$table • ${status.toUpperCase()}'),
              subtitle: Text(
                'Requested: ${_formatTimestamp(requestedAt)}\n'
                'Range: ${_formatTimestamp(rangeStart)} - ${_formatTimestamp(rangeEnd)}'
                '${completedAt != null ? '\nCompleted: ${_formatTimestamp(completedAt)}' : ''}',
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class _RfmJobStatus extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('analytics_jobs')
          .doc('rfm_scoring')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Text('No runs recorded yet.');
        }
        final data = snapshot.data!.data() ?? {};
        final Timestamp? lastRunAt = data['lastRunAt'] as Timestamp?;
        final int customerCount = (data['customerCount'] as num?)?.toInt() ?? 0;
        final Timestamp? lookbackStart = data['lookbackStart'] as Timestamp?;
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text('Updated ${_formatTimestamp(lastRunAt)}'),
          subtitle: Text(
            'Customers scored: $customerCount'
            '${lookbackStart != null ? '\nLookback: ${_formatTimestamp(lookbackStart)}' : ''}',
          ),
        );
      },
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return '-';
    final date = timestamp.toDate();
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
