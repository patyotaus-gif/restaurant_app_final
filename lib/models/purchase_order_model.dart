// lib/models/purchase_order_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum PoStatus { draft, ordered, received, cancelled }

class PurchaseOrderItem {
  final String productId;
  final String productName;
  final double quantity;
  final double cost; // Cost for the total quantity

  PurchaseOrderItem({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.cost,
  });

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'cost': cost,
    };
  }

  factory PurchaseOrderItem.fromMap(Map<String, dynamic> map) {
    return PurchaseOrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toDouble() ?? 0.0,
      cost: (map['cost'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class PurchaseOrder {
  final String id;
  final String poNumber;
  final String supplierId;
  final String supplierName;
  final List<PurchaseOrderItem> items;
  final PoStatus status;
  final Timestamp orderDate;
  final double totalAmount;

  PurchaseOrder({
    required this.id,
    required this.poNumber,
    required this.supplierId,
    required this.supplierName,
    required this.items,
    required this.status,
    required this.orderDate,
    required this.totalAmount,
  });

  factory PurchaseOrder.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return PurchaseOrder(
      id: doc.id,
      poNumber: data['poNumber'] ?? '',
      supplierId: data['supplierId'] ?? '',
      supplierName: data['supplierName'] ?? '',
      items:
          (data['items'] as List<dynamic>?)
              ?.map((item) => PurchaseOrderItem.fromMap(item))
              .toList() ??
          [],
      status: PoStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? PoStatus.draft.name),
      ),
      orderDate: data['orderDate'] ?? Timestamp.now(),
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
