import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurant_models/restaurant_models.dart';
class NotificationsRepository {
  final FirebaseFirestore db;
  NotificationsRepository(this.db);

  Stream<List<AppNotification>> watch({
    required String tenantId,
    int limit = 100,
  }) {
    return db
        .collection('notifications')
        .where('tenantId', isEqualTo: tenantId)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((s) => s.docs.map(AppNotification.fromDoc).toList());
  }

  Future<void> markSeen(String id, String uid) async {
    await db.collection('notifications').doc(id).update({
      'seenBy.$uid': FieldValue.serverTimestamp(),
    });
  }

  Future<void> publishSystemNotification({
    required String tenantId,
    required String title,
    required String message,
    String type = 'PRINT_SPOOLER',
    String severity = 'warning',
    Map<String, dynamic>? data,
  }) async {
    await db.collection('notifications').add({
      'tenantId': tenantId,
      'title': title,
      'message': message,
      'type': type,
      'severity': severity,
      'data': data ?? <String, dynamic>{},
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': <String, dynamic>{},
    });
  }
}
