// lib/end_of_day_report_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'cart_provider.dart';
class EndOfDayReportPage extends StatefulWidget {
  const EndOfDayReportPage({super.key});

  @override
  State<EndOfDayReportPage> createState() => _EndOfDayReportPageState();
}

class _EndOfDayReportPageState extends State<EndOfDayReportPage> {
  late Future<Map<String, dynamic>> _reportData;

  @override
  void initState() {
    super.initState();
    _reportData = _generateReport();
  }

  // --- FIX: อัปเดตฟังก์ชันนี้ให้รู้จัก Expenses ---
  Future<Map<String, dynamic>> _generateReport() async {
    final now = DateTime.now();
    final startOfToday = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day),
    );
    final endOfToday = Timestamp.fromDate(
      DateTime(now.year, now.month, now.day, 23, 59, 59),
    );

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('timestamp', isGreaterThanOrEqualTo: startOfToday)
        .where('timestamp', isLessThanOrEqualTo: endOfToday)
        .get();

    final refundsSnapshot = await FirebaseFirestore.instance
        .collection('refunds')
        .where('refundTimestamp', isGreaterThanOrEqualTo: startOfToday)
        .where('refundTimestamp', isLessThanOrEqualTo: endOfToday)
        .get();

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('transactionDate', isGreaterThanOrEqualTo: startOfToday)
        .where('transactionDate', isLessThanOrEqualTo: endOfToday)
        .get();

    final Map<String, dynamic> payload = {
      'orders': ordersSnapshot.docs
          .map((doc) {
            final data = doc.data();
            final rawItems =
                (data['items'] as List<dynamic>? ?? <dynamic>[]).whereType<Map<String, dynamic>>();
            return {
              'orderType': data['orderType']?.toString() ?? '',
              'total': (data['total'] as num?)?.toDouble() ?? 0.0,
              'items': rawItems
                  .map(
                    (item) => {
                      'name': item['name']?.toString() ?? 'Item',
                      'quantity': (item['quantity'] as num?)?.toDouble() ?? 0.0,
                    },
                  )
                  .toList(),
            };
          })
          .toList(),
      'refunds': refundsSnapshot.docs
          .map((doc) => (doc.data()['totalRefundAmount'] as num?)?.toDouble() ?? 0.0)
          .toList(),
      'expenses': expensesSnapshot.docs
          .map((doc) => (doc.data()['amount'] as num?)?.toDouble() ?? 0.0)
          .toList(),
    };

    final summary = await compute(_aggregateEndOfDayReport, payload);
    summary['totalOrders'] = ordersSnapshot.docs.length;
    return summary;
  }
  // ---------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'End of Day Report (${DateFormat('dd MMM yyyy').format(DateTime.now())})',
        ),
        backgroundColor: Colors.indigo,
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _reportData,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error generating report.'));
          }
          if (!snapshot.hasData ||
              ((snapshot.data!['totalOrders'] as int) == 0 &&
                  (snapshot.data!['totalExpenses'] as double) == 0)) {
            return const Center(child: Text('No data for today.'));
          }

          final data = snapshot.data!;
          final Map<String, int> itemSummary = data['itemSummary'];

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildSummaryCard(data),
              const SizedBox(height: 20),
              _buildItemBreakdownCard(itemSummary),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.money),
                    label: const Text('Cash Reconciliation'),
                    onPressed: () => _showCashReconciliationDialog(data),
                  ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.receipt_long),
                    label: const Text('Generate Shift Z Report'),
                    onPressed: _showShiftZReportDialog,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.lock_clock),
                label: const Text('CLOSE OUT DAY'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: () {
                  Provider.of<CartProvider>(
                    context,
                    listen: false,
                  ).resetTakeawayCounter();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Daily operations closed. Takeaway counter reset.',
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  // --- FIX: อัปเดต UI ให้แสดงผลกำไรสุทธิ ---
  Widget _buildSummaryCard(Map<String, dynamic> data) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Financial Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildSummaryRow(
              'Gross Revenue:',
              '${(data['totalRevenue'] as double).toStringAsFixed(2)} Baht',
            ),
            _buildSummaryRow(
              'Total Refunds:',
              '- ${(data['totalRefundAmount'] as double).toStringAsFixed(2)} Baht',
            ),
            _buildSummaryRow(
              'Total Expenses:',
              '- ${(data['totalExpenses'] as double).toStringAsFixed(2)} Baht',
            ),
            const Divider(),
            _buildSummaryRow(
              'Net Profit:',
              '${(data['netProfit'] as double).toStringAsFixed(2)} Baht',
              isBold: true,
            ),
            const Divider(),
            const Text(
              'Order Summary',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            _buildSummaryRow(
              'Total Orders:',
              (data['totalOrders'] as int).toString(),
            ),
            _buildSummaryRow(
              'Dine-in Orders:',
              (data['dineInCount'] as int).toString(),
            ),
            _buildSummaryRow(
              'Takeaway Orders:',
              (data['takeawayCount'] as int).toString(),
            ),
          ],
        ),
      ),
    );
  }
  // ------------------------------------------

  Widget _buildItemBreakdownCard(Map<String, int> itemSummary) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Item Sales Breakdown',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const Divider(height: 20),
            if (itemSummary.isEmpty)
              const Text('No items sold today.')
            else
              ...itemSummary.entries.map((entry) {
                return _buildSummaryRow('${entry.key}:', 'x${entry.value}');
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String value, {bool isBold = false}) {
    final profit = double.tryParse(value.replaceAll(' Baht', ''));
    Color? valueColor;
    if (isBold && profit != null) {
      valueColor = profit >= 0 ? Colors.green.shade700 : Colors.red.shade700;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showCashReconciliationDialog(Map<String, dynamic> reportData) {
    final expectedCash =
        (reportData['totalRevenue'] as double? ?? 0) -
        (reportData['totalRefundAmount'] as double? ?? 0);
    final shiftController = TextEditingController(text: 'Shift Z');
    final countedCashController = TextEditingController();
    final noteController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('End of Day Cash Reconciliation'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Expected cash on hand: ${expectedCash.toStringAsFixed(2)} Baht',
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: shiftController,
                  decoration: const InputDecoration(
                    labelText: 'Shift name / identifier',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: countedCashController,
                  decoration: const InputDecoration(
                    labelText: 'Counted cash total',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  decoration: const InputDecoration(
                    labelText: 'Notes (optional)',
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final counted =
                    double.tryParse(countedCashController.text.trim()) ?? 0.0;
                final shiftName = shiftController.text.trim().isEmpty
                    ? 'Shift Z'
                    : shiftController.text.trim();
                final difference = counted - expectedCash;

                try {
                  await FirebaseFirestore.instance
                      .collection('cash_reconciliations')
                      .add({
                        'shiftName': shiftName,
                        'expectedCash': expectedCash,
                        'countedCash': counted,
                        'difference': difference,
                        'notes': noteController.text.trim(),
                        'recordedAt': Timestamp.now(),
                      });
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Cash reconciliation saved.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Failed to save reconciliation: ${e.toString()}',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showShiftZReportDialog() {
    final shiftController = TextEditingController(text: 'Shift Z');
    TimeOfDay startTime = const TimeOfDay(hour: 0, minute: 0);
    TimeOfDay endTime = const TimeOfDay(hour: 23, minute: 59);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Generate Shift Z Report'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: shiftController,
                      decoration: const InputDecoration(
                        labelText: 'Shift name',
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton.icon(
                          icon: const Icon(Icons.schedule),
                          label: Text('Start: ${startTime.format(context)}'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: startTime,
                            );
                            if (picked != null) {
                              setStateDialog(() => startTime = picked);
                            }
                          },
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.schedule_outlined),
                          label: Text('End: ${endTime.format(context)}'),
                          onPressed: () async {
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: endTime,
                            );
                            if (picked != null) {
                              setStateDialog(() => endTime = picked);
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'The report will include all completed orders within the selected time range.',
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(dialogContext).pop();
                    await _generateShiftZReport(
                      shiftController.text.trim().isEmpty
                          ? 'Shift Z'
                          : shiftController.text.trim(),
                      startTime,
                      endTime,
                    );
                  },
                  child: const Text('Generate'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _generateShiftZReport(
    String shiftName,
    TimeOfDay start,
    TimeOfDay end,
  ) async {
    final now = DateTime.now();
    var startDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      start.hour,
      start.minute,
    );
    var endDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      end.hour,
      end.minute,
    );

    if (!endDateTime.isAfter(startDateTime)) {
      endDateTime = endDateTime.add(const Duration(days: 1));
    }

    final startTimestamp = Timestamp.fromDate(startDateTime);
    final endTimestamp = Timestamp.fromDate(endDateTime);

    try {
      final ordersSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .get();

      final filteredOrders = ordersSnapshot.docs.where((doc) {
        final data = doc.data();
        final timestamp =
            (data['completedAt'] as Timestamp?) ??
            (data['timestamp'] as Timestamp?);
        if (timestamp == null) return false;
        final time = timestamp.toDate();
        return !time.isBefore(startDateTime) && !time.isAfter(endDateTime);
      }).toList();

      double totalRevenue = 0;
      final Map<String, int> itemSummary = {};

      for (final doc in filteredOrders) {
        final data = doc.data();
        totalRevenue += (data['total'] as num?)?.toDouble() ?? 0.0;
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          if (item is! Map<String, dynamic>) continue;
          final name = item['name'] as String? ?? 'Item';
          final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
          if (quantity <= 0) continue;
          itemSummary.update(
            name,
            (value) => value + quantity,
            ifAbsent: () => quantity,
          );
        }
      }

      final refundsSnapshot = await FirebaseFirestore.instance
          .collection('refunds')
          .where('refundTimestamp', isGreaterThanOrEqualTo: startTimestamp)
          .where('refundTimestamp', isLessThanOrEqualTo: endTimestamp)
          .get();

      double totalRefundAmount = 0;
      for (final doc in refundsSnapshot.docs) {
        totalRefundAmount +=
            (doc.data()['totalRefundAmount'] as num?)?.toDouble() ?? 0.0;
      }

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('transactionDate', isGreaterThanOrEqualTo: startTimestamp)
          .where('transactionDate', isLessThanOrEqualTo: endTimestamp)
          .get();

      double totalExpenses = 0;
      for (final doc in expensesSnapshot.docs) {
        totalExpenses += (doc.data()['amount'] as num?)?.toDouble() ?? 0.0;
      }

      final netSales = totalRevenue - totalRefundAmount - totalExpenses;

      final sortedItems = itemSummary.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      await FirebaseFirestore.instance.collection('shift_reports').add({
        'shiftName': shiftName,
        'start': startTimestamp,
        'end': endTimestamp,
        'generatedAt': Timestamp.now(),
        'totalRevenue': totalRevenue,
        'totalOrders': filteredOrders.length,
        'totalRefundAmount': totalRefundAmount,
        'totalExpenses': totalExpenses,
        'netSales': netSales,
        'itemSummary': Map.fromEntries(sortedItems),
      });

      if (mounted) {
        final timeFormat = DateFormat('HH:mm');
        await showDialog(
          context: context,
          builder: (context) {
          return AlertDialog(
            title: const Text('Shift Z Report Summary'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Shift: $shiftName'),
                  Text(
                    'Period: ${timeFormat.format(startDateTime)} - ${timeFormat.format(endDateTime)}',
                  ),
                  const SizedBox(height: 12),
                  Text('Orders Completed: ${filteredOrders.length}'),
                  Text(
                    'Gross Revenue: ${totalRevenue.toStringAsFixed(2)} Baht',
                  ),
                  Text('Refunds: ${totalRefundAmount.toStringAsFixed(2)} Baht'),
                  Text('Expenses: ${totalExpenses.toStringAsFixed(2)} Baht'),
                  const Divider(),
                  Text(
                    'Net Sales: ${netSales.toStringAsFixed(2)} Baht',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  if (sortedItems.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text(
                      'Items Sold',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    ...sortedItems.map(
                      (entry) => Text('${entry.key}: ${entry.value}'),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Shift Z report saved.')));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate Shift Z report: $e')),
        );
      }
    }
  }
}

Map<String, dynamic> _aggregateEndOfDayReport(
    Map<String, dynamic> payload) {
  final List<dynamic> ordersRaw = payload['orders'] as List<dynamic>? ?? [];
  final List<dynamic> refundsRaw = payload['refunds'] as List<dynamic>? ?? [];
  final List<dynamic> expensesRaw = payload['expenses'] as List<dynamic>? ?? [];

  double totalRevenue = 0;
  int dineInCount = 0;
  int takeawayCount = 0;
  final Map<String, int> itemSummary = <String, int>{};

  for (final dynamic entry in ordersRaw) {
    if (entry is! Map<String, dynamic>) {
      continue;
    }
    final String orderType = (entry['orderType'] as String? ?? '').toLowerCase();
    final double total = (entry['total'] as num?)?.toDouble() ?? 0.0;
    totalRevenue += total;

    if (orderType == 'dine-in' || orderType == 'dine in') {
      dineInCount += 1;
    } else {
      takeawayCount += 1;
    }

    final List<dynamic> items = entry['items'] as List<dynamic>? ?? [];
    for (final dynamic rawItem in items) {
      if (rawItem is! Map<String, dynamic>) {
        continue;
      }
      final String name = rawItem['name']?.toString() ?? 'Item';
      final int quantity = ((rawItem['quantity'] as num?)?.round()) ?? 0;
      itemSummary.update(
        name,
        (value) => value + quantity,
        ifAbsent: () => quantity,
      );
    }
  }

  final double totalRefundAmount = refundsRaw.fold<double>(
    0,
    (previousValue, element) =>
        previousValue + (element is num ? element.toDouble() : 0.0),
  );
  final double totalExpenses = expensesRaw.fold<double>(
    0,
    (previousValue, element) =>
        previousValue + (element is num ? element.toDouble() : 0.0),
  );
  final double netProfit = totalRevenue - totalRefundAmount - totalExpenses;

  return {
    'totalRevenue': totalRevenue,
    'totalRefundAmount': totalRefundAmount,
    'totalExpenses': totalExpenses,
    'netProfit': netProfit,
    'dineInCount': dineInCount,
    'takeawayCount': takeawayCount,
    'itemSummary': itemSummary,
  };
}
