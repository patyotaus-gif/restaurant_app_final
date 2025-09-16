// lib/clock_in_out_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'models/employee_model.dart';
import 'models/time_record_model.dart';

class ClockInOutPage extends StatefulWidget {
  const ClockInOutPage({super.key});

  @override
  State<ClockInOutPage> createState() => _ClockInOutPageState();
}

class _ClockInOutPageState extends State<ClockInOutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<TimeRecord?> _getLatestTimeRecord(String employeeId) async {
    final snapshot = await _firestore
        .collection('time_records')
        .where('employeeId', isEqualTo: employeeId)
        .orderBy('clockInTime', descending: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return TimeRecord.fromFirestore(snapshot.docs.first);
    }
    return null;
  }

  void _handleClockInOut(Employee employee, TimeRecord? latestRecord) {
    // --- DEBUG: Add this print statement ---
    debugPrint("--- Handling Clock In/Out for ${employee.name} ---");
    debugPrint("Latest Record ID: ${latestRecord?.id}");
    debugPrint("Latest Record ClockOutTime: ${latestRecord?.clockOutTime}");
    // ------------------------------------

    final pinController = TextEditingController();
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Enter PIN for ${employee.name}'),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          obscureText: true,
          maxLength: 4,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (pinController.text == employee.pin) {
                Navigator.of(dialogContext).pop();

                try {
                  if (latestRecord != null &&
                      latestRecord.clockOutTime == null) {
                    await _firestore
                        .collection('time_records')
                        .doc(latestRecord.id)
                        .update({'clockOutTime': Timestamp.now()});

                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('${employee.name} clocked out.')),
                    );
                  } else {
                    await _firestore.collection('time_records').add({
                      'employeeId': employee.id,
                      'employeeName': employee.name,
                      'clockInTime': Timestamp.now(),
                      'clockOutTime': null,
                    });

                    scaffoldMessenger.showSnackBar(
                      SnackBar(content: Text('${employee.name} clocked in.')),
                    );
                  }

                  setState(() {});
                } catch (e) {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } else {
                scaffoldMessenger.showSnackBar(
                  const SnackBar(content: Text('Invalid PIN!')),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Staff Clock In / Out')),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('employees').orderBy('name').snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final employees = snapshot.data!.docs
              .map((doc) => Employee.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: employees.length,
            itemBuilder: (context, index) {
              final employee = employees[index];
              return FutureBuilder<TimeRecord?>(
                future: _getLatestTimeRecord(employee.id),
                builder: (context, recordSnapshot) {
                  if (recordSnapshot.connectionState ==
                      ConnectionState.waiting) {
                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(employee.name.substring(0, 1)),
                      ),
                      title: Text(employee.name),
                      subtitle: const Text('Loading status...'),
                    );
                  }

                  final latestRecord = recordSnapshot.data;
                  final bool isClockedIn =
                      latestRecord != null && latestRecord.clockOutTime == null;

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isClockedIn
                          ? Colors.green.shade100
                          : Colors.grey.shade200,
                      child: Text(employee.name.substring(0, 1)),
                    ),
                    title: Text(employee.name),
                    subtitle: Text(
                      isClockedIn
                          ? 'Clocked in at ${DateFormat('HH:mm').format(latestRecord!.clockInTime.toDate())}'
                          : 'Clocked Out',
                      style: TextStyle(
                        color: isClockedIn
                            ? Colors.green.shade800
                            : Colors.grey.shade700,
                        fontWeight: isClockedIn
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                    onTap: () => _handleClockInOut(employee, latestRecord),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
