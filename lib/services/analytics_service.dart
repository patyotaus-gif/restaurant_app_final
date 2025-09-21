import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';

class AnalyticsService {
  AnalyticsService(FirebaseFirestore firestore) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Future<DocumentReference<Map<String, dynamic>>> queueBigQueryExport({
    required DateTime start,
    required DateTime end,
    String? table,
  }) async {
    final payload = <String, dynamic>{
      'rangeStart': Timestamp.fromDate(start),
      'rangeEnd': Timestamp.fromDate(end),
      'requestedAt': Timestamp.now(),
      if (table != null) 'table': table,
      'status': 'queued',
    };
    return _firestore.collection('analytics_exports').add(payload);
  }

  Future<void> calculateAndStoreRfmScores({
    DateTime? lookback,
    List<String> statuses = const ['completed', 'paid', 'serving'],
  }) async {
    final DateTime now = DateTime.now();
    Query<Map<String, dynamic>> query = _firestore.collection('orders');
    if (lookback != null) {
      query = query.where(
        'timestamp',
        isGreaterThanOrEqualTo: Timestamp.fromDate(lookback),
      );
    }
    if (statuses.isNotEmpty) {
      query = query.where('status', whereIn: statuses);
    }

    final ordersSnapshot = await query.get();

    if (ordersSnapshot.docs.isEmpty) {
      await _firestore.collection('analytics_jobs').doc('rfm_scoring').set({
        'lastRunAt': Timestamp.fromDate(now),
        'customerCount': 0,
        'lookbackStart': lookback != null ? Timestamp.fromDate(lookback) : null,
      }, SetOptions(merge: true));
      return;
    }

    final Map<String, _RfmAccumulator> aggregates = {};

    for (final doc in ordersSnapshot.docs) {
      final data = doc.data();
      final String? customerId = data['customerId'] as String?;
      if (customerId == null || customerId.isEmpty) {
        continue;
      }
      final Timestamp? ts = data['timestamp'] as Timestamp?;
      final double orderTotal = (data['total'] as num?)?.toDouble() ?? 0.0;
      if (ts == null) {
        continue;
      }
      final DateTime orderTime = ts.toDate();
      final aggregate = aggregates.putIfAbsent(
        customerId,
        () => _RfmAccumulator(),
      );
      aggregate.orderCount += 1;
      aggregate.totalSpend += orderTotal;
      if (aggregate.lastOrderAt == null ||
          aggregate.lastOrderAt!.isBefore(orderTime)) {
        aggregate.lastOrderAt = orderTime;
      }
    }

    if (aggregates.isEmpty) {
      return;
    }

    final List<double> recencyDays = aggregates.values
        .map(
          (value) =>
              (now.difference(value.lastOrderAt ?? now).inDays).toDouble(),
        )
        .toList();
    final List<double> frequencyCounts = aggregates.values
        .map((value) => value.orderCount.toDouble())
        .toList();
    final List<double> monetaryValues = aggregates.values
        .map((value) => value.totalSpend)
        .toList();

    final _ScoreThresholds recencyThresholds = _buildThresholds(
      recencyDays,
      lowerIsBetter: true,
    );
    final _ScoreThresholds frequencyThresholds = _buildThresholds(
      frequencyCounts,
    );
    final _ScoreThresholds monetaryThresholds = _buildThresholds(
      monetaryValues,
    );

    final entries = aggregates.entries.toList();
    const int batchSize = 400;

    for (var i = 0; i < entries.length; i += batchSize) {
      final chunk = entries.sublist(i, min(i + batchSize, entries.length));
      final batch = _firestore.batch();
      for (final entry in chunk) {
        final customerId = entry.key;
        final data = entry.value;
        final double recencyValue =
            (now.difference(data.lastOrderAt ?? now).inDays).toDouble();
        final recencyScore = _score(
          recencyValue,
          recencyThresholds,
          lowerIsBetter: true,
        );
        final frequencyScore = _score(
          data.orderCount.toDouble(),
          frequencyThresholds,
        );
        final monetaryScore = _score(data.totalSpend, monetaryThresholds);
        final totalScore = recencyScore + frequencyScore + monetaryScore;
        final segment = _segmentCustomer(
          recencyScore,
          frequencyScore,
          monetaryScore,
        );
        final averageOrderValue = data.orderCount == 0
            ? 0.0
            : data.totalSpend / data.orderCount;
        final customerRef = _firestore.collection('customers').doc(customerId);
        batch.set(customerRef, {
          'rfm': {
            'recencyScore': recencyScore,
            'frequencyScore': frequencyScore,
            'monetaryScore': monetaryScore,
            'totalScore': totalScore,
            'segment': segment,
            'lastOrderAt': data.lastOrderAt != null
                ? Timestamp.fromDate(data.lastOrderAt!)
                : null,
            'orderCount': data.orderCount,
            'averageOrderValue': averageOrderValue,
            'totalSpend': data.totalSpend,
            'updatedAt': Timestamp.fromDate(now),
          },
        }, SetOptions(merge: true));
      }
      await batch.commit();
    }

    await _firestore.collection('analytics_jobs').doc('rfm_scoring').set({
      'lastRunAt': Timestamp.fromDate(now),
      'customerCount': aggregates.length,
      'lookbackStart': lookback != null ? Timestamp.fromDate(lookback) : null,
    }, SetOptions(merge: true));
  }

  _ScoreThresholds _buildThresholds(
    List<double> values, {
    bool lowerIsBetter = false,
  }) {
    if (values.isEmpty) {
      return const _ScoreThresholds();
    }
    final sorted = List<double>.from(values)..sort();
    if (lowerIsBetter) {
      return _ScoreThresholds(
        p20: sorted[_indexFor(sorted.length, 0.2)],
        p40: sorted[_indexFor(sorted.length, 0.4)],
        p60: sorted[_indexFor(sorted.length, 0.6)],
        p80: sorted[_indexFor(sorted.length, 0.8)],
      );
    }
    return _ScoreThresholds(
      p20: sorted[_indexFor(sorted.length, 0.2)],
      p40: sorted[_indexFor(sorted.length, 0.4)],
      p60: sorted[_indexFor(sorted.length, 0.6)],
      p80: sorted[_indexFor(sorted.length, 0.8)],
    );
  }

  int _score(
    double value,
    _ScoreThresholds thresholds, {
    bool lowerIsBetter = false,
  }) {
    if (lowerIsBetter) {
      if (value <= thresholds.p20) return 5;
      if (value <= thresholds.p40) return 4;
      if (value <= thresholds.p60) return 3;
      if (value <= thresholds.p80) return 2;
      return 1;
    }
    if (value >= thresholds.p80) return 5;
    if (value >= thresholds.p60) return 4;
    if (value >= thresholds.p40) return 3;
    if (value >= thresholds.p20) return 2;
    return 1;
  }

  String _segmentCustomer(int r, int f, int m) {
    if (r >= 4 && f >= 4 && m >= 4) {
      return 'Champions';
    }
    if (r >= 4 && f >= 3) {
      return 'Loyal Customers';
    }
    if (r >= 3 && f >= 3 && m >= 3) {
      return 'Potential Loyalist';
    }
    if (r <= 2 && f >= 4) {
      return 'At Risk';
    }
    if (r <= 2 && m <= 2) {
      return 'Hibernating';
    }
    return 'Needs Attention';
  }

  static int _indexFor(int length, double percentile) {
    if (length <= 1) {
      return 0;
    }
    final index = (percentile * (length - 1)).round();
    return index.clamp(0, length - 1);
  }
}

class _RfmAccumulator {
  int orderCount = 0;
  double totalSpend = 0.0;
  DateTime? lastOrderAt;
}

class _ScoreThresholds {
  const _ScoreThresholds({
    this.p20 = 0,
    this.p40 = 0,
    this.p60 = 0,
    this.p80 = 0,
  });

  final double p20;
  final double p40;
  final double p60;
  final double p80;
}
