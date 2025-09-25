import 'package:cloud_firestore/cloud_firestore.dart';
class AppNotification {
  final String id;
  final String type;
  final String title;
  final String message;
  final String severity;
  final DateTime createdAt;
  final Map<String, dynamic> data;
  final Map<String, dynamic> seenBy;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.severity,
    required this.createdAt,
    required this.data,
    required this.seenBy,
  });

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return AppNotification(
      id: doc.id,
      type: d['type'] ?? 'INFO',
      title: d['title'] ?? '',
      message: d['message'] ?? '',
      severity: d['severity'] ?? 'info',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      data: Map<String, dynamic>.from(d['data'] ?? {}),
      seenBy: Map<String, dynamic>.from(d['seenBy'] ?? {}),
    );
  }

  bool isSeen(String uid) => seenBy.containsKey(uid);
}
