import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String type;
  final String description;
  final String actorId;
  final DateTime timestamp;
  final String? storeId;
  final Map<String, dynamic>? metadata;

  const AuditLogEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.actorId,
    required this.timestamp,
    this.storeId,
    this.metadata,
  });

  factory AuditLogEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return AuditLogEntry(
      id: doc.id,
      type: data['type'] as String? ?? 'unknown',
      description: data['description'] as String? ?? '',
      actorId: data['actorId'] as String? ?? 'system',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storeId: data['storeId'] as String?,
      metadata: data['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'description': description,
      'actorId': actorId,
      'timestamp': Timestamp.fromDate(timestamp),
      if (storeId != null) 'storeId': storeId,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
