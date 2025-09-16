// lib/kitchen_display_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class KitchenDisplayPage extends StatelessWidget {
  const KitchenDisplayPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kitchen Display System (KDS)'),
        backgroundColor: Colors.blueGrey[800],
      ),
      backgroundColor: Colors.blueGrey[900],
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', isEqualTo: 'preparing')
            .orderBy('timestamp', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Something went wrong',
                style: TextStyle(color: Colors.white),
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                'No active orders',
                style: TextStyle(color: Colors.white70, fontSize: 24),
              ),
            );
          }

          final orderDocs = snapshot.data!.docs;

          return GridView.builder(
            padding: const EdgeInsets.all(16.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 0.8,
            ),
            itemCount: orderDocs.length,
            itemBuilder: (context, index) {
              final order = orderDocs[index];
              return _OrderCard(orderDoc: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatefulWidget {
  final DocumentSnapshot orderDoc;

  const _OrderCard({required this.orderDoc});

  @override
  State<_OrderCard> createState() => _OrderCardState();
}

class _OrderCardState extends State<_OrderCard> {
  void _toggleItemComplete(int itemIndex) {
    List<dynamic> items = List.from(
      (widget.orderDoc.data() as Map<String, dynamic>)['items'] ?? [],
    );
    Map<String, dynamic> item = Map<String, dynamic>.from(items[itemIndex]);
    bool currentStatus = item['isComplete'] ?? false;
    item['isComplete'] = !currentStatus;
    items[itemIndex] = item;
    widget.orderDoc.reference.update({'items': items});
  }

  @override
  Widget build(BuildContext context) {
    final orderData = widget.orderDoc.data() as Map<String, dynamic>;
    final items = (orderData['items'] ?? []) as List<dynamic>;
    final timestamp = (orderData['timestamp'] as Timestamp).toDate();
    final orderIdentifier = orderData['orderIdentifier'] ?? 'N/A';
    final orderType = orderData['orderType'] ?? '';
    final bool allItemsComplete = items.every(
      (item) => item['isComplete'] == true,
    );

    return Card(
      color: Colors.blueGrey[700],
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderIdentifier,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 20,
                    color: Colors.white,
                  ),
                ),
                Chip(
                  label: Text(orderType),
                  backgroundColor: orderType == 'Dine-in'
                      ? Colors.orange
                      : Colors.teal,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                ),
              ],
            ),
            Text(
              DateFormat('HH:mm:ss').format(timestamp),
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const Divider(color: Colors.white54, height: 20),

            Expanded(
              child: ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final item = items[index];
                  final bool isComplete = item['isComplete'] ?? false;
                  // --- NEW: LOGIC TO DISPLAY MODIFIERS ---
                  final List<dynamic> modifiers =
                      item['selectedModifiers'] ?? [];
                  final modifierWidgets = modifiers.map((mod) {
                    return Padding(
                      padding: const EdgeInsets.only(left: 24.0, top: 2.0),
                      child: Text(
                        "- ${mod['optionName']}",
                        style: TextStyle(
                          fontSize: 14,
                          color: isComplete ? Colors.white38 : Colors.white70,
                          fontStyle: FontStyle.italic,
                          decoration: isComplete
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                        ),
                      ),
                    );
                  }).toList();
                  // ----------------------------------------

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        onTap: () => _toggleItemComplete(index),
                        title: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${item['quantity']}x',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: isComplete
                                    ? Colors.white54
                                    : Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                item['name'],
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isComplete
                                      ? Colors.white54
                                      : Colors.white,
                                  decoration: isComplete
                                      ? TextDecoration.lineThrough
                                      : TextDecoration.none,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...modifierWidgets, // <-- DISPLAY MODIFIERS HERE
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: allItemsComplete
                    ? () async {
                        await widget.orderDoc.reference.update({
                          'status': 'serving',
                        });
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  disabledBackgroundColor: Colors.grey.shade600,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'READY',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
