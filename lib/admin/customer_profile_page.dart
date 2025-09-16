import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../models/customer_model.dart';

class CustomerProfilePage extends StatefulWidget {
  final String customerId;

  const CustomerProfilePage({super.key, required this.customerId});

  @override
  State<CustomerProfilePage> createState() => _CustomerProfilePageState();
}

class _CustomerProfilePageState extends State<CustomerProfilePage> {
  void _showEditNotesDialog(BuildContext context, Customer customer) {
    final notesController = TextEditingController(text: customer.notes);
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Edit Customer Notes'),
          content: TextField(
            controller: notesController,
            maxLines: 4,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter notes here (e.g., allergies, preferences)',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customer.id)
                    .update({'notes': notesController.text});
                Navigator.of(ctx).pop();
                // We need to trigger a rebuild to show the new note
                setState(() {});
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTierChip(String tier) {
    Color chipColor;
    switch (tier) {
      case 'Gold':
        chipColor = Colors.amber.shade700;
        break;
      case 'Platinum':
        chipColor = Colors.blueGrey.shade600;
        break;
      default:
        chipColor = Colors.grey.shade600;
    }
    return Chip(
      label: Text(
        tier,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      backgroundColor: chipColor,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  Widget _buildInfoCard(Customer customer) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.person, size: 40, color: Colors.indigo),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      customer.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _buildTierChip(customer.tier),
                  ],
                ),
              ],
            ),
            const Divider(height: 30),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn(
                  'Loyalty Points',
                  customer.loyaltyPoints.toString(),
                ),
                _buildStatColumn(
                  'Lifetime Spend',
                  '฿${customer.lifetimeSpend.toStringAsFixed(2)}',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatColumn(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor: Colors.indigo,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('customers')
            .doc(widget.customerId)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('Error loading customer data.'));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('Customer not found.'));
          }

          final customer = Customer.fromFirestore(snapshot.data!);

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildInfoCard(customer),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.notes),
                title: const Text('Customer Notes'),
                subtitle: Text(
                  customer.notes.isNotEmpty
                      ? customer.notes
                      : 'No notes yet. Tap the pencil to add one.',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showEditNotesDialog(context, customer),
                ),
              ),
              const Divider(),
              _OrderHistoryList(customerId: widget.customerId),
            ],
          );
        },
      ),
    );
  }
}

class _OrderHistoryList extends StatelessWidget {
  final String customerId;
  const _OrderHistoryList({required this.customerId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8.0),
          child: ListTile(
            leading: Icon(Icons.history),
            title: Text('Order History'),
          ),
        ),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('orders')
              .where('customerId', isEqualTo: customerId)
              .where('status', isEqualTo: 'completed')
              .orderBy('timestamp', descending: true)
              .limit(20)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No completed orders found for this customer.'),
                ),
              );
            }

            final orderDocs = snapshot.data!.docs;

            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: orderDocs.length,
              itemBuilder: (context, index) {
                final orderData =
                    orderDocs[index].data() as Map<String, dynamic>;
                final timestamp = (orderData['timestamp'] as Timestamp)
                    .toDate();
                final formattedDate = DateFormat(
                  'dd MMM yyyy - HH:mm',
                ).format(timestamp);
                final items = (orderData['items'] as List<dynamic>);

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4.0),
                  child: ExpansionTile(
                    title: Text(orderData['orderIdentifier'] ?? 'Order'),
                    subtitle: Text(formattedDate),
                    trailing: Text(
                      '฿${(orderData['total'] as num).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    children: items.map<Widget>((item) {
                      return ListTile(
                        title: Text(
                          item is Map
                              ? item['name'] ?? 'Unknown Item'
                              : 'Invalid Item',
                        ),
                        trailing: Text(
                          item is Map ? '${item['quantity']} x' : '',
                        ),
                        dense: true,
                      );
                    }).toList(),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}
