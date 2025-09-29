import 'package:cloud_firestore/cloud_firestore.dart';

/// Adds convenience helpers for building queries that only fetch documents
/// around the "edges" of a time window. This keeps real-time listeners light
/// weight while still surfacing the most relevant, recent data.
extension EdgeFilteredQuery<T> on Query<T> {
  /// Applies upper/lower timestamp boundaries to the query.
  ///
  /// [field] must point to a Firestore `Timestamp` field.
  /// [lookback] constrains the query to documents newer than `now - lookback`.
  /// [lookahead] constrains the query to documents older than `now + lookahead`.
  ///
  /// Both [startAt] and [endAt] override the relative offsets when provided.
  Query<T> edgeFilter({
    required String field,
    Duration? lookback,
    Duration? lookahead,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    Query<T> query = this;
    final DateTime now = DateTime.now();
    final DateTime? lowerBound = startAt ??
        (lookback != null ? now.subtract(lookback) : null);
    final DateTime? upperBound = endAt ??
        (lookahead != null ? now.add(lookahead) : null);

    if (lowerBound != null) {
      query = query.where(
        field,
        isGreaterThanOrEqualTo: Timestamp.fromDate(lowerBound),
      );
    }
    if (upperBound != null) {
      query = query.where(
        field,
        isLessThanOrEqualTo: Timestamp.fromDate(upperBound),
      );
    }
    return query;
  }
}
