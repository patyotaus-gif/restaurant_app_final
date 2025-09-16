// lib/end_of_day_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

    final querySnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('status', isEqualTo: 'completed')
        .where('timestamp', isGreaterThanOrEqualTo: startOfToday)
        .where('timestamp', isLessThanOrEqualTo: endOfToday)
        .get();

    double totalRevenue = 0;
    int dineInCount = 0;
    int takeawayCount = 0;
    Map<String, int> itemSummary = {};

    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      totalRevenue += (data['total'] as num).toDouble();
      if (data['orderType'] == 'Dine-in') {
        dineInCount++;
      } else {
        takeawayCount++;
      }
      final items = data['items'] as List<dynamic>;
      for (var item in items) {
        final name = item['name'] as String;
        final quantity = item['quantity'] as int;
        itemSummary.update(
          name,
          (value) => value + quantity,
          ifAbsent: () => quantity,
        );
      }
    }

    final refundsSnapshot = await FirebaseFirestore.instance
        .collection('refunds')
        .where('refundTimestamp', isGreaterThanOrEqualTo: startOfToday)
        .where('refundTimestamp', isLessThanOrEqualTo: endOfToday)
        .get();

    double totalRefundAmount = 0;
    for (var doc in refundsSnapshot.docs) {
      totalRefundAmount += (doc.data()['totalRefundAmount'] as num).toDouble();
    }

    final expensesSnapshot = await FirebaseFirestore.instance
        .collection('expenses')
        .where('transactionDate', isGreaterThanOrEqualTo: startOfToday)
        .where('transactionDate', isLessThanOrEqualTo: endOfToday)
        .get();

    double totalExpenses = 0;
    for (var doc in expensesSnapshot.docs) {
      totalExpenses += (doc.data()['amount'] as num).toDouble();
    }

    final netProfit = totalRevenue - totalRefundAmount - totalExpenses;

    return {
      'totalRevenue': totalRevenue,
      'totalRefundAmount': totalRefundAmount,
      'totalExpenses': totalExpenses,
      'netProfit': netProfit,
      'totalOrders': querySnapshot.docs.length,
      'dineInCount': dineInCount,
      'takeawayCount': takeawayCount,
      'itemSummary': itemSummary,
    };
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
}
