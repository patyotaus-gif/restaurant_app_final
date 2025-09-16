// lib/admin/time_report_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/time_record_model.dart';
import '../models/employee_model.dart';

// Helper class to hold calculated data
class EmployeeWorkSummary {
  final Employee employee;
  double totalHours = 0;
  List<TimeRecord> records = [];

  EmployeeWorkSummary({required this.employee});
}

class TimeReportPage extends StatefulWidget {
  const TimeReportPage({super.key});

  @override
  State<TimeReportPage> createState() => _TimeReportPageState();
}

class _TimeReportPageState extends State<TimeReportPage> {
  DateTimeRange _selectedDateRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  late Future<List<EmployeeWorkSummary>> _reportData;

  @override
  void initState() {
    super.initState();
    _fetchReportData();
  }

  void _fetchReportData() {
    setState(() {
      _reportData = _generateReport();
    });
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final newDateRange = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedDateRange,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
    );
    if (newDateRange != null) {
      setState(() {
        _selectedDateRange = newDateRange;
      });
      _fetchReportData();
    }
  }

  Future<List<EmployeeWorkSummary>> _generateReport() async {
    // 1. Fetch all employees
    final employeesSnapshot = await FirebaseFirestore.instance
        .collection('employees')
        .get();
    final employees = employeesSnapshot.docs
        .map((doc) => Employee.fromFirestore(doc))
        .toList();

    final summaries = {
      for (var emp in employees) emp.id: EmployeeWorkSummary(employee: emp),
    };

    // 2. Fetch relevant time records
    final start = Timestamp.fromDate(_selectedDateRange.start);
    // Adjust end date to include the whole day
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

    final recordsSnapshot = await FirebaseFirestore.instance
        .collection('time_records')
        .where('clockInTime', isGreaterThanOrEqualTo: start)
        .where('clockInTime', isLessThanOrEqualTo: end)
        .orderBy('clockInTime')
        .get();

    // 3. Process records and calculate hours
    for (var doc in recordsSnapshot.docs) {
      final record = TimeRecord.fromFirestore(doc);
      if (summaries.containsKey(record.employeeId)) {
        summaries[record.employeeId]!.records.add(record);
        if (record.clockOutTime != null) {
          final duration = record.clockOutTime!.toDate().difference(
            record.clockInTime.toDate(),
          );
          summaries[record.employeeId]!.totalHours += duration.inMinutes / 60.0;
        }
      }
    }

    return summaries.values.toList()
      ..sort((a, b) => a.employee.name.compareTo(b.employee.name));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Work Hours Report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: const Text('Select Date Range'),
                  onPressed: () => _selectDateRange(context),
                ),
                const SizedBox(width: 16),
                Text(
                  '${DateFormat('dd MMM').format(_selectedDateRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange.end)}',
                ),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: FutureBuilder<List<EmployeeWorkSummary>>(
              future: _reportData,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('No data for this period.'));
                }

                final summaries = snapshot.data!;
                return ListView.builder(
                  itemCount: summaries.length,
                  itemBuilder: (context, index) {
                    final summary = summaries[index];
                    return ExpansionTile(
                      leading: CircleAvatar(
                        child: Text(summary.employee.name.substring(0, 1)),
                      ),
                      title: Text(summary.employee.name),
                      subtitle: Text(
                        'Total Hours: ${summary.totalHours.toStringAsFixed(2)}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      children: summary.records.map((record) {
                        final clockIn = record.clockInTime.toDate();
                        final clockOut = record.clockOutTime?.toDate();
                        String durationStr = 'Still Clocked In';
                        if (clockOut != null) {
                          final duration = clockOut.difference(clockIn);
                          durationStr =
                              '${(duration.inMinutes / 60.0).toStringAsFixed(2)} hrs';
                        }
                        return ListTile(
                          title: Text(
                            DateFormat('dd MMM yyyy').format(clockIn),
                          ),
                          subtitle: Text(
                            '${DateFormat('HH:mm').format(clockIn)} - ${clockOut != null ? DateFormat('HH:mm').format(clockOut) : '...'}',
                          ),
                          trailing: Text(durationStr),
                        );
                      }).toList(),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
