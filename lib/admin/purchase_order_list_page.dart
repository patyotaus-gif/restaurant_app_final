// lib/admin/purchase_order_list_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_models/restaurant_models.dart';
class PurchaseOrderListPage extends StatelessWidget {
  const PurchaseOrderListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Purchase Orders')),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('purchase_orders')
            .orderBy('orderDate', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No purchase orders found.'));
          }

          final pos = snapshot.data!.docs
              .map((doc) => PurchaseOrder.fromFirestore(doc))
              .toList();

          return ListView.builder(
            itemCount: pos.length,
            itemBuilder: (context, index) {
              final po = pos[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text('PO #${po.poNumber} - ${po.supplierName}'),
                  subtitle: Text(
                    'Date: ${DateFormat('dd MMM yyyy').format(po.orderDate.toDate())}',
                  ),
                  trailing: po.status == PoStatus.ordered
                      ? ElevatedButton(
                          onPressed: () {
                            FirebaseFirestore.instance
                                .collection('purchase_orders')
                                .doc(po.id)
                                .update({'status': PoStatus.received.name});
                          },
                          child: const Text('Mark as Received'),
                        )
                      : Chip(
                          label: Text(po.status.name.toUpperCase()),
                          backgroundColor: po.status == PoStatus.received
                              ? Colors.green.shade100
                              : Colors.grey.shade200,
                        ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/admin/purchase-orders/create'),
        tooltip: 'Create New PO',
        child: const Icon(Icons.add),
      ),
    );
  }
}
