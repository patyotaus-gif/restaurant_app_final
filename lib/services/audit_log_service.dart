import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/audit_log_entry.dart';

class AuditLogService {
  AuditLogService(this._firestore);

  final FirebaseFirestore _firestore;

  Future<void> logEvent({
    required String tenantId,
    required String type,
    required String description,
    required String actorId,
    String? storeId,
    Map<String, dynamic>? metadata,
  }) async {
    final entry = AuditLogEntry(
      id: '',
      type: type,
      description: description,
      actorId: actorId,
      storeId: storeId,
      timestamp: DateTime.now(),
      tenantId: tenantId,
      metadata: metadata,
    );
    await _firestore.collection('auditLogs').add(entry.toFirestore());
  }

  Stream<List<AuditLogEntry>> watchLogs({
    required String tenantId,
    String? storeId,
    int limit = 100,
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('auditLogs')
        .where('tenantId', isEqualTo: tenantId);
    if (storeId != null && storeId.isNotEmpty) {
      query = query.where('storeId', isEqualTo: storeId);
    }
    query = query.orderBy('timestamp', descending: true).limit(limit);
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => AuditLogEntry.fromFirestore(doc))
          .toList(growable: false);
    });
  }
}
