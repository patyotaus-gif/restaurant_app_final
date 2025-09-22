import 'package:cloud_firestore/cloud_firestore.dart';

class AuditLogEntry {
  final String id;
  final String type;
  final String description;
  final String actorId;
  final DateTime timestamp;
  final String? storeId;
  final String? tenantId;
  final String? collection;
  final String? documentId;
  final Map<String, dynamic>? metadata;

  const AuditLogEntry({
    required this.id,
    required this.type,
    required this.description,
    required this.actorId,
    required this.timestamp,
    this.storeId,
    this.tenantId,
    this.collection,
    this.documentId,
    this.metadata,
  });

  factory AuditLogEntry.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    final rawMetadata = data['metadata'];
    Map<String, dynamic>? metadata;
    if (rawMetadata is Map<String, dynamic>) {
      metadata = Map<String, dynamic>.from(rawMetadata);
    } else if (rawMetadata is Map) {
      metadata = rawMetadata.map(
        (key, value) => MapEntry(key.toString(), value),
      );
    }
    return AuditLogEntry(
      id: doc.id,
      type: data['type'] as String? ?? 'unknown',
      description: data['description'] as String? ?? '',
      actorId: data['actorId'] as String? ?? 'system',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      storeId: data['storeId'] as String?,
      tenantId: data['tenantId'] as String?,
      collection: data['collection'] as String?,
      documentId: data['documentId'] as String?,
      metadata: metadata,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'type': type,
      'description': description,
      'actorId': actorId,
      'timestamp': Timestamp.fromDate(timestamp),
      if (storeId != null) 'storeId': storeId,
      if (tenantId != null) 'tenantId': tenantId,
      if (collection != null) 'collection': collection,
      if (documentId != null) 'documentId': documentId,
      if (metadata != null) 'metadata': metadata,
    };
  }
}
