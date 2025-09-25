import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
typedef SchemaMigrationTask =
    Future<void> Function(FirebaseFirestore firestore, String tenantId);

class SchemaMigration {
  const SchemaMigration({
    required this.id,
    required this.description,
    required this.task,
  });

  final String id;
  final String description;
  final SchemaMigrationTask task;
}

enum SchemaMigrationStatus { idle, running, completed, failed }

class SchemaMigrationRunner extends ChangeNotifier {
  SchemaMigrationRunner(this._firestore, {List<SchemaMigration>? migrations})
    : _migrations = List.unmodifiable(migrations ?? defaultSchemaMigrations);

  final FirebaseFirestore _firestore;
  final List<SchemaMigration> _migrations;

  SchemaMigrationStatus _status = SchemaMigrationStatus.idle;
  SchemaMigration? _currentMigration;
  Object? _lastError;
  Future<void>? _activeRun;
  String? _activeTenantId;

  SchemaMigrationStatus get status => _status;
  SchemaMigration? get currentMigration => _currentMigration;
  Object? get lastError => _lastError;
  String? get activeTenantId => _activeTenantId;

  void ensureMigrationsForTenant(String? tenantId) {
    if (tenantId == null) {
      return;
    }
    if (_activeRun != null && _activeTenantId == tenantId) {
      return;
    }
    _activeTenantId = tenantId;
    _activeRun = _executeForTenant(tenantId).whenComplete(() {
      _activeRun = null;
    });
  }

  Future<void> _executeForTenant(String tenantId) async {
    _status = SchemaMigrationStatus.running;
    _lastError = null;
    notifyListeners();

    final statusCollection = _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('_schema_migrations');

    for (final migration in _migrations) {
      _currentMigration = migration;
      notifyListeners();

      final snapshot = await statusCollection.doc(migration.id).get();
      if (snapshot.exists && snapshot.data()?['status'] == 'completed') {
        continue;
      }

      try {
        await migration.task(_firestore, tenantId);
        await statusCollection.doc(migration.id).set({
          'status': 'completed',
          'description': migration.description,
          'completedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (error, stack) {
        final wrapped = SchemaMigrationException(migration.id, error, stack);
        await statusCollection.doc(migration.id).set({
          'status': 'failed',
          'description': migration.description,
          'failedAt': FieldValue.serverTimestamp(),
          'lastError': error.toString(),
        }, SetOptions(merge: true));
        _status = SchemaMigrationStatus.failed;
        _lastError = wrapped;
        notifyListeners();
        throw wrapped;
      }
    }

    _currentMigration = null;
    _status = SchemaMigrationStatus.completed;
    notifyListeners();
  }
}

class SchemaMigrationException implements Exception {
  SchemaMigrationException(this.migrationId, this.error, this.stackTrace);

  final String migrationId;
  final Object error;
  final StackTrace stackTrace;

  @override
  String toString() =>
      'SchemaMigrationException(migrationId: $migrationId, error: $error)';
}

Future<void> _writeInChunks(
  FirebaseFirestore firestore,
  Iterable<DocumentReference<Map<String, dynamic>>> refs,
  Map<String, dynamic> data,
) async {
  WriteBatch batch = firestore.batch();
  var writes = 0;
  for (final ref in refs) {
    batch.set(ref, data, SetOptions(merge: true));
    writes++;
    if (writes >= 400) {
      await batch.commit();
      batch = firestore.batch();
      writes = 0;
    }
  }
  if (writes > 0) {
    await batch.commit();
  }
}

Future<void> _ensureFeatureFlagSchemaVersion(
  FirebaseFirestore firestore,
  String tenantId,
) async {
  final docRef = firestore.collection('featureFlags').doc(tenantId);
  await firestore.runTransaction((transaction) async {
    final snapshot = await transaction.get(docRef);
    final existing = snapshot.data();
    final currentVersion = existing?['schemaVersion'] as int?;
    if (currentVersion != null && currentVersion >= 1) {
      return;
    }
    transaction.set(docRef, {
      'tenantId': tenantId,
      'schemaVersion': 1,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  });
}

Future<void> _ensureStoreTimezone(
  FirebaseFirestore firestore,
  String tenantId,
) async {
  final query = await firestore
      .collection('stores')
      .where('tenantId', isEqualTo: tenantId)
      .where('timezone', isNull: true)
      .get();

  if (query.docs.isEmpty) {
    return;
  }

  await _writeInChunks(firestore, query.docs.map((doc) => doc.reference), {
    'timezone': 'Asia/Bangkok',
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

Future<void> _ensureStoreIsActive(
  FirebaseFirestore firestore,
  String tenantId,
) async {
  final query = await firestore
      .collection('stores')
      .where('tenantId', isEqualTo: tenantId)
      .where('isActive', isNull: true)
      .get();

  if (query.docs.isEmpty) {
    return;
  }

  await _writeInChunks(firestore, query.docs.map((doc) => doc.reference), {
    'isActive': true,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

final List<SchemaMigration> defaultSchemaMigrations = [
  SchemaMigration(
    id: '20240901_feature_flag_schema_version',
    description:
        'Ensure feature flag documents declare schema version metadata.',
    task: _ensureFeatureFlagSchemaVersion,
  ),
  SchemaMigration(
    id: '20240902_default_store_timezone',
    description: 'Populate missing store timezone with Asia/Bangkok.',
    task: _ensureStoreTimezone,
  ),
  SchemaMigration(
    id: '20240903_default_store_status',
    description: 'Mark stores without an explicit status as active.',
    task: _ensureStoreIsActive,
  ),
];
