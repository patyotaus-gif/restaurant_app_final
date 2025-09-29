import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'services/query_edge_filter.dart';
class NotificationsRepository {
  final FirebaseFirestore db;
  NotificationsRepository(this.db);

  Stream<List<AppNotification>> watch({
    required String tenantId,
    int limit = 100,
    Duration lookback = const Duration(days: 14),
  }) {
    Query<Map<String, dynamic>> query = db
        .collection('notifications')
        .where('tenantId', isEqualTo: tenantId)
        .edgeFilter(field: 'createdAt', lookback: lookback)
        .orderBy('createdAt', descending: true)
        .limit(limit);

    return query
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
