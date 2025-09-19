import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class PromotionRules {
  final double? minSubtotal;
  final int? minQuantity;
  final List<String> requiredCategories;
  final List<String> orderTypes;
  final DateTime? startDate;
  final DateTime? endDate;

  const PromotionRules({
    this.minSubtotal,
    this.minQuantity,
    this.requiredCategories = const [],
    this.orderTypes = const [],
    this.startDate,
    this.endDate,
  });

  factory PromotionRules.fromMap(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) {
      return const PromotionRules();
    }

    DateTime? _parseDate(dynamic value) {
      if (value is Timestamp) {
        return value.toDate();
      }
      if (value is DateTime) {
        return value;
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    List<String> _stringList(dynamic value) {
      if (value is Iterable) {
        return value
            .map((e) => e.toString().trim())
            .where((element) => element.isNotEmpty)
            .toList();
      }
      return const [];
    }

    return PromotionRules(
      minSubtotal: (data['minSubtotal'] as num?)?.toDouble(),
      minQuantity: (data['minQuantity'] as num?)?.toInt(),
      requiredCategories: _stringList(data['requiredCategories']),
      orderTypes: _stringList(data['orderTypes']),
      startDate: _parseDate(data['startDate']),
      endDate: _parseDate(data['endDate']),
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (minSubtotal != null) map['minSubtotal'] = minSubtotal;
    if (minQuantity != null) map['minQuantity'] = minQuantity;
    if (requiredCategories.isNotEmpty) {
      map['requiredCategories'] = requiredCategories;
    }
    if (orderTypes.isNotEmpty) {
      map['orderTypes'] = orderTypes;
    }
    if (startDate != null) {
      map['startDate'] = Timestamp.fromDate(startDate!);
    }
    if (endDate != null) {
      map['endDate'] = Timestamp.fromDate(endDate!);
    }
    return map;
  }

  bool get hasConstraints {
    return minSubtotal != null ||
        minQuantity != null ||
        requiredCategories.isNotEmpty ||
        orderTypes.isNotEmpty ||
        startDate != null ||
        endDate != null;
  }

  String? validate({
    required double subtotal,
    required int itemCount,
    required Set<String> categories,
    required String? orderType,
    DateTime? currentTime,
  }) {
    final now = currentTime ?? DateTime.now();
    if (startDate != null && now.isBefore(startDate!)) {
      return 'This promotion will be available on '
          '${DateFormat('d MMM yyyy').format(startDate!)}.';
    }
    if (endDate != null && now.isAfter(endDate!)) {
      return 'This promotion has expired.';
    }
    if (minSubtotal != null && subtotal < minSubtotal!) {
      return 'This promotion requires a minimum subtotal of '
          '฿${minSubtotal!.toStringAsFixed(2)}.';
    }
    if (minQuantity != null && itemCount < minQuantity!) {
      return 'Add at least $minQuantity item(s) to use this promotion.';
    }
    if (requiredCategories.isNotEmpty &&
        requiredCategories.every(
          (category) => !categories.contains(category),
        )) {
      return 'This promotion requires at least one item from: '
          '${requiredCategories.join(', ')}.';
    }
    if (orderTypes.isNotEmpty) {
      if (orderType == null || !orderTypes.contains(orderType)) {
        return 'This promotion is only valid for '
            '${orderTypes.map(_humanizeOrderType).join(', ')} orders.';
      }
    }
    return null;
  }

  bool isApplicable({
    required double subtotal,
    required int itemCount,
    required Set<String> categories,
    required String? orderType,
    DateTime? currentTime,
  }) {
    return validate(
          subtotal: subtotal,
          itemCount: itemCount,
          categories: categories,
          orderType: orderType,
          currentTime: currentTime,
        ) ==
        null;
  }

  String summary() {
    final parts = <String>[];
    if (minSubtotal != null) {
      parts.add('Min ฿${minSubtotal!.toStringAsFixed(2)}');
    }
    if (minQuantity != null) {
      parts.add('Min items: $minQuantity');
    }
    if (requiredCategories.isNotEmpty) {
      parts.add('Categories: ${requiredCategories.join(', ')}');
    }
    if (orderTypes.isNotEmpty) {
      parts.add('Order type: ${orderTypes.map(_humanizeOrderType).join(', ')}');
    }
    if (startDate != null) {
      parts.add('From ${DateFormat('d MMM').format(startDate!)}');
    }
    if (endDate != null) {
      parts.add('Until ${DateFormat('d MMM').format(endDate!)}');
    }
    return parts.join(' • ');
  }

  String _humanizeOrderType(String type) {
    switch (type) {
      case 'dineIn':
        return 'Dine-in';
      case 'takeaway':
        return 'Takeaway';
      case 'retail':
        return 'Retail';
      default:
        return type;
    }
  }
}

class Promotion {
  final String id;
  final String code;
  final String description;
  final String type; // 'fixed' or 'percentage'
  final double value;
  final bool isActive;
  final PromotionRules rules;

  Promotion({
    required this.id,
    required this.code,
    required this.description,
    required this.type,
    required this.value,
    required this.isActive,
    PromotionRules? rules,
  }) : rules = rules ?? const PromotionRules();

  factory Promotion.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Promotion(
      id: doc.id,
      code: data['code'] ?? '',
      description: data['description'] ?? '',
      type: data['type'] ?? 'fixed',
      value: (data['value'] as num?)?.toDouble() ?? 0.0,
      isActive: data['isActive'] ?? false,
      rules: PromotionRules.fromMap(data['rules'] as Map<String, dynamic>?),
    );
  }

  Map<String, dynamic> toFirestore() {
    final map = {
      'code': code,
      'description': description,
      'type': type,
      'value': value,
      'isActive': isActive,
    };
    if (rules.hasConstraints) {
      map['rules'] = rules.toMap();
    } else {
      map['rules'] = {};
    }
    return map;
  }
}
