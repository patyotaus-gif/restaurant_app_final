// lib/models/time_record_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class TimeRecord {
  final String id;
  final String employeeId;
  final String employeeName;
  final Timestamp clockInTime;
  final Timestamp? clockOutTime;

  TimeRecord({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.clockInTime,
    this.clockOutTime,
  });

  factory TimeRecord.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return TimeRecord(
      id: doc.id,
      employeeId: data['employeeId'] ?? '',
      employeeName: data['employeeName'] ?? '',
      clockInTime: data['clockInTime'] ?? Timestamp.now(),
      clockOutTime: data['clockOutTime'],
    );
  }
}
