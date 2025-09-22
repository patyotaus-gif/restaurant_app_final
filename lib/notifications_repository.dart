import 'package:cloud_firestore/cloud_firestore.dart';
import 'models/notification_model.dart';

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
}
