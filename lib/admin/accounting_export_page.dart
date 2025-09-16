import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';

class AccountingExportPage extends StatefulWidget {
  const AccountingExportPage({super.key});

  @override
  State<AccountingExportPage> createState() => _AccountingExportPageState();
}

class _AccountingExportPageState extends State<AccountingExportPage> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now(),
    end: DateTime.now(),
  );
  bool _isExporting = false;

  Future<void> _selectDateRange(BuildContext context) async {
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
    }
  }

  String _formatDate(DateTime date) {
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _exportSalesData() async {
    setState(() => _isExporting = true);
    try {
      final start = Timestamp.fromDate(
        DateTime(
          _selectedDateRange.start.year,
          _selectedDateRange.start.month,
          _selectedDateRange.start.day,
        ),
      );
      final end = Timestamp.fromDate(
        DateTime(
          _selectedDateRange.end.year,
          _selectedDateRange.end.month,
          _selectedDateRange.end.day,
          23,
          59,
          59,
        ),
      );

      final querySnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .where('status', isEqualTo: 'completed')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

      List<List<dynamic>> rows = [];
      rows.add([
        "Date",
        "Time",
        "OrderID",
        "Identifier",
        "Type",
        "Subtotal",
        "Discount",
        "Total",
        "Promo Code",
        "Customer",
      ]);

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        rows.add([
          DateFormat('yyyy-MM-dd').format(timestamp),
          DateFormat('HH:mm:ss').format(timestamp),
          doc.id,
          data['orderIdentifier'] ?? '',
          data['orderType'] ?? '',
          data['subtotal'] ?? 0.0,
          data['discount'] ?? 0.0,
          data['total'] ?? 0.0,
          data['promotionCode'] ?? 'N/A',
          data['customerName'] ?? 'N/A',
        ]);
      }
      _generateAndDownloadCsv(rows, "Sales");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting sales: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _exportExpensesData() async {
    setState(() => _isExporting = true);
    try {
      final start = Timestamp.fromDate(
        DateTime(
          _selectedDateRange.start.year,
          _selectedDateRange.start.month,
          _selectedDateRange.start.day,
        ),
      );
      final end = Timestamp.fromDate(
        DateTime(
          _selectedDateRange.end.year,
          _selectedDateRange.end.month,
          _selectedDateRange.end.day,
          23,
          59,
          59,
        ),
      );

      final expensesSnapshot = await FirebaseFirestore.instance
          .collection('expenses')
          .where('transactionDate', isGreaterThanOrEqualTo: start)
          .where('transactionDate', isLessThanOrEqualTo: end)
          .get();
      final poSnapshot = await FirebaseFirestore.instance
          .collection('purchase_orders')
          .where('timestamp', isGreaterThanOrEqualTo: start)
          .where('timestamp', isLessThanOrEqualTo: end)
          .get();

      List<List<dynamic>> rows = [];
      rows.add(["Date", "Type", "Description/Supplier", "Amount"]);

      for (var doc in expensesSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['transactionDate'] as Timestamp).toDate();
        rows.add([
          DateFormat('yyyy-MM-dd').format(timestamp),
          'Expense',
          data['supplierName'] ?? '',
          data['amount'] ?? 0.0,
        ]);
      }
      for (var doc in poSnapshot.docs) {
        final data = doc.data();
        final timestamp = (data['timestamp'] as Timestamp).toDate();
        rows.add([
          DateFormat('yyyy-MM-dd').format(timestamp),
          'Purchase Order',
          data['supplier'] ?? '',
          data['totalAmount'] ?? 0.0,
        ]);
      }
      _generateAndDownloadCsv(rows, "Expenses");
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error exporting expenses: $e')));
      }
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  Future<void> _generateAndDownloadCsv(
    List<List<dynamic>> rows,
    String reportType,
  ) async {
    const listToCsvConverter = ListToCsvConverter();
    final csvString = listToCsvConverter.convert(rows);
    final bytes = utf8.encode(csvString);
    final data = Uint8List.fromList(bytes);

    final startDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.start);
    final endDate = DateFormat('yyyy-MM-dd').format(_selectedDateRange.end);
    final fileName = '$reportType-Report-$startDate-to-$endDate.csv';

    // --- FIX: Removed the invalid 'ext' parameter ---
    await FileSaver.instance.saveFile(
      name: fileName,
      bytes: data,
      mimeType: MimeType.csv,
    );
    // ---------------------------------------------
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Accounting Export'),
        backgroundColor: Colors.indigo,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Text(
              'Select a date range to export data.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Choose Date Range'),
                  onPressed: () => _selectDateRange(context),
                ),
                const SizedBox(width: 20),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Start: ${_formatDate(_selectedDateRange.start)}'),
                    Text('End:   ${_formatDate(_selectedDateRange.end)}'),
                  ],
                ),
              ],
            ),
            const Divider(height: 40),
            SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                icon: _isExporting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.receipt_long_outlined),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export Sales Data (.csv)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isExporting ? null : _exportSalesData,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 300,
              child: ElevatedButton.icon(
                icon: _isExporting
                    ? const SizedBox.shrink()
                    : const Icon(Icons.payment_outlined),
                label: Text(
                  _isExporting ? 'Exporting...' : 'Export Expenses Data (.csv)',
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isExporting ? null : _exportExpensesData,
              ),
            ),
            if (_isExporting)
              const Padding(
                padding: EdgeInsets.only(top: 20.0),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}
