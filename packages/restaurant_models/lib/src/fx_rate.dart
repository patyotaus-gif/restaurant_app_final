import 'package:cloud_firestore/cloud_firestore.dart';
class FxRate {
  FxRate({
    required this.baseCurrency,
    required this.quoteCurrency,
    required this.rate,
    DateTime? asOf,
  }) : asOf = asOf ?? DateTime.now();

  final String baseCurrency;
  final String quoteCurrency;
  final double rate;
  final DateTime asOf;

  String get pairKey =>
      '${baseCurrency.toUpperCase()}_${quoteCurrency.toUpperCase()}';

  Map<String, dynamic> toMap() {
    return {
      'baseCurrency': baseCurrency.toUpperCase(),
      'quoteCurrency': quoteCurrency.toUpperCase(),
      'rate': rate,
      'asOf': Timestamp.fromDate(asOf),
    };
  }

  static FxRate fromMap(Map<String, dynamic> map) {
    final timestamp = map['asOf'];
    DateTime? asOf;
    if (timestamp is Timestamp) {
      asOf = timestamp.toDate();
    } else if (timestamp is String) {
      asOf = DateTime.tryParse(timestamp);
    }
    return FxRate(
      baseCurrency: (map['baseCurrency'] as String? ?? 'THB').toUpperCase(),
      quoteCurrency: (map['quoteCurrency'] as String? ?? 'THB').toUpperCase(),
      rate: (map['rate'] as num?)?.toDouble() ?? 1.0,
      asOf: asOf,
    );
  }
}
