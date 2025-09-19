// lib/all_orders_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'checkout_page.dart';
import 'item_refund_page.dart';
import 'admin/pdf_receipt_page.dart';

// 1. Convert to StatefulWidget
class AllOrdersPage extends StatefulWidget {
  const AllOrdersPage({super.key});

  @override
  State<AllOrdersPage> createState() => _AllOrdersPageState();
}

class _AllOrdersPageState extends State<AllOrdersPage> {
  // 2. Add state variables for search functionality
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Add a listener to update the search query whenever the text changes
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildStatusButton(
    String orderId,
    String currentStatus,
    String nextStatus,
    Color color,
  ) {
    if (currentStatus == 'completed' || currentStatus == 'refunded') {
      return const SizedBox.shrink();
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: color),
      onPressed: currentStatus == nextStatus
          ? null
          : () {
              FirebaseFirestore.instance
                  .collection('orders')
                  .doc(orderId)
                  .update({'status': nextStatus});
            },
      child: Text(nextStatus, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _buildCheckoutButton(
    BuildContext context,
    String orderId,
    String currentStatus,
    Map<String, dynamic> orderData,
  ) {
    if (currentStatus != 'serving') {
      return const SizedBox.shrink();
    }
    return ElevatedButton(
      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
      child: const Text('Checkout', style: TextStyle(color: Colors.white)),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CheckoutPage(
              orderId: orderId,
              totalAmount: (orderData['total'] as num).toDouble(),
              orderIdentifier: orderData['orderIdentifier'] ?? 'Order',
              subtotal: (orderData['subtotal'] as num?)?.toDouble() ?? 0.0,
              discountAmount:
                  (orderData['discount'] as num?)?.toDouble() ?? 0.0,
              serviceChargeAmount:
                  (orderData['serviceChargeAmount'] as num?)?.toDouble() ?? 0.0,
              serviceChargeRate:
                  (orderData['serviceChargeRate'] as num?)?.toDouble() ?? 0.0,
              tipAmount: (orderData['tipAmount'] as num?)?.toDouble() ?? 0.0,
              splitCount: (orderData['splitCount'] as int?) ?? 1,
              splitAmountPerGuest: (orderData['splitAmountPerGuest'] as num?)
                  ?.toDouble(),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRefundButton(BuildContext context, DocumentSnapshot orderDoc) {
    final orderData = orderDoc.data() as Map<String, dynamic>;
    final currentStatus = orderData['status'] ?? '';
    final hasPartialRefund = orderData['hasPartialRefund'] ?? false;

    if (currentStatus != 'completed') {
      return const SizedBox.shrink();
    }

    return TextButton.icon(
      icon: Icon(Icons.undo, color: Colors.red.shade400),
      label: Text(
        hasPartialRefund ? 'Refund Again' : 'Refund',
        style: TextStyle(color: Colors.red.shade400),
      ),
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ItemRefundPage(orderDoc: orderDoc),
          ),
        );
      },
    );
  }

  Widget _buildPrintButton(
    BuildContext context,
    String currentStatus,
    Map<String, dynamic> orderData,
  ) {
    if (currentStatus != 'completed' && currentStatus != 'refunded') {
      return const SizedBox.shrink();
    }
    return IconButton(
      icon: Icon(Icons.print, color: Colors.grey.shade700),
      tooltip: 'View Receipt',
      onPressed: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfReceiptPage(orderData: orderData),
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'preparing':
        return Colors.orange;
      case 'serving':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'refunded':
        return Colors.grey.shade600;
      case 'new':
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('All Orders'),
        backgroundColor: Colors.indigo,
      ),
      // 3. Add Column to hold search bar and the list
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Search by Table, Takeaway #, or Customer Name',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.0),
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('orders')
                  .orderBy('timestamp', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Something went wrong'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                // 4. Filter logic
                final allDocs = snapshot.data!.docs;
                final filteredDocs = _searchQuery.isEmpty
                    ? allDocs
                    : allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        final identifier =
                            (data['orderIdentifier'] as String?)
                                ?.toLowerCase() ??
                            '';
                        final customerName =
                            (data['customerName'] as String?)?.toLowerCase() ??
                            '';
                        return identifier.contains(_searchQuery) ||
                            customerName.contains(_searchQuery);
                      }).toList();

                if (filteredDocs.isEmpty) {
                  return const Center(child: Text('No matching orders found.'));
                }

                // 5. Use filteredDocs in ListView
                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    DocumentSnapshot orderDoc = filteredDocs[index];
                    Map<String, dynamic> orderData =
                        orderDoc.data()! as Map<String, dynamic>;
                    String currentStatus = orderData['status'] ?? 'new';
                    Timestamp timestamp = orderDoc['timestamp'];
                    String formattedDate = DateFormat(
                      'dd MMM yyyy, HH:mm',
                    ).format(timestamp.toDate());
                    List<dynamic> items = orderData['items'] ?? [];
                    String orderIdentifier =
                        orderData['orderIdentifier'] ?? 'Order';

                    final isRefunded = currentStatus == 'refunded';
                    final hasPartialRefund =
                        orderData['hasPartialRefund'] ?? false;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      elevation: isRefunded ? 1 : 3,
                      color: isRefunded ? Colors.grey.shade200 : null,
                      child: ExpansionTile(
                        title: Text(
                          orderIdentifier,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isRefunded
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        subtitle: Text(
                          'Total: ${(orderData['total'] ?? 0).toStringAsFixed(2)} Baht • $formattedDate',
                        ),
                        trailing: hasPartialRefund && !isRefunded
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Chip(
                                    label: const Text('PARTIALLY REFUNDED'),
                                    backgroundColor: Colors.orange.shade300,
                                    padding: const EdgeInsets.all(4),
                                    labelStyle: const TextStyle(
                                      fontSize: 10,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    label: Text(
                                      currentStatus.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    backgroundColor: _getStatusColor(
                                      currentStatus,
                                    ),
                                  ),
                                ],
                              )
                            : Chip(
                                label: Text(
                                  currentStatus.toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getStatusColor(currentStatus),
                              ),
                        children: [
                          ...items.map((item) {
                            return ListTile(
                              title: Text(
                                '- ${item['name']}',
                                style: TextStyle(
                                  decoration: isRefunded
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              subtitle: item['description'] != null
                                  ? Text('  (${item['description']})')
                                  : null,
                              trailing: Text('${item['quantity']} x'),
                              dense: true,
                            );
                          }).toList(),
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8.0,
                              vertical: 4.0,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildStatusButton(
                                  orderDoc.id,
                                  currentStatus,
                                  'preparing',
                                  Colors.orange,
                                ),
                                const SizedBox(width: 8),
                                _buildStatusButton(
                                  orderDoc.id,
                                  currentStatus,
                                  'serving',
                                  Colors.blue.shade400,
                                ),
                                const SizedBox(width: 8),
                                _buildCheckoutButton(
                                  context,
                                  orderDoc.id,
                                  currentStatus,
                                  orderData,
                                ),
                                const Spacer(),
                                _buildRefundButton(context, orderDoc),
                                _buildPrintButton(
                                  context,
                                  currentStatus,
                                  orderData,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
