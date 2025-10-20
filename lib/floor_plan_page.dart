// lib/floor_plan_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import 'auth_service.dart';
import 'cart_provider.dart'; // <-- Import CartProvider
import 'order_dashboard_page.dart';

class FloorPlanPage extends StatelessWidget {
  const FloorPlanPage({super.key});
  final int tableCount = 30;

  // --- Function to show the check-in dialog for a reservation ---
  void _showReservationCheckInDialog(
    BuildContext context,
    Reservation reservation,
  ) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Reservation for Table ${reservation.tableNumber}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Name: ${reservation.customerName}'),
              Text('Guests: ${reservation.numberOfGuests}'),
              Text('Phone: ${reservation.phoneNumber}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final cart = Provider.of<CartProvider>(context, listen: false);
                final navigator = Navigator.of(ctx);
                final router = GoRouter.of(context);

                // 1. Clear any previous cart
                cart.clear();

                // 2. Set the table number for the new order
                cart.selectDineIn(reservation.tableNumber);

                // 3. Find customer profile from phone number
                final customerQuery = await FirebaseFirestore.instance
                    .collection('customers')
                    .where('phoneNumber', isEqualTo: reservation.phoneNumber)
                    .limit(1)
                    .get();

                if (customerQuery.docs.isNotEmpty) {
                  cart.setCustomer(customerQuery.docs.first);
                }

                // (Optional) Update reservation status
                // You might want to add a status field to your reservation documents
                // e.g., FirebaseFirestore.instance.collection('reservations').doc(reservation.id).update({'status': 'arrived'});

                // 4. Close the dialog and navigate to the order page
                navigator.pop();
                router.push('/dashboard');
              },
              child: const Text('Check-in & Start Order'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Restaurant Floor Plan'),
        backgroundColor: Colors.indigo,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/order-type-selection'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.receipt_long),
            tooltip: 'Order History',
            onPressed: () {
              context.push('/all-orders');
            },
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            tooltip: 'Admin Panel',
            onPressed: () {
              context.push('/admin');
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              final authService = Provider.of<AuthService>(
                context,
                listen: false,
              );
              await authService.signOut();
              if (context.mounted) {
                context.go('/login');
              }
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('status', whereNotIn: ['completed', 'refunded'])
            .snapshots(),
        builder: (context, ordersSnapshot) {
          if (ordersSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (ordersSnapshot.hasError) {
            return const Center(child: Text('Error fetching orders.'));
          }

          final activeOrders = ordersSnapshot.data?.docs ?? [];
          final Map<String, DocumentSnapshot> occupiedTableMap = {
            for (var doc in activeOrders)
              if ((doc.data() as Map<String, dynamic>).containsKey(
                    'orderIdentifier',
                  ) &&
                  (doc.data() as Map<String, dynamic>)['orderIdentifier']
                      .toString()
                      .startsWith('Table '))
                (doc.data() as Map<String, dynamic>)['orderIdentifier']
                        .toString()
                        .replaceAll('Table ', ''):
                    doc,
          };

          final now = DateTime.now();
          final startOfToday = Timestamp.fromDate(
            DateTime(now.year, now.month, now.day),
          );
          final endOfToday = Timestamp.fromDate(
            DateTime(now.year, now.month, now.day, 23, 59, 59),
          );

          return FutureBuilder<QuerySnapshot>(
            future: FirebaseFirestore.instance
                .collection('reservations')
                .where('reservationTime', isGreaterThanOrEqualTo: startOfToday)
                .where('reservationTime', isLessThanOrEqualTo: endOfToday)
                .get(),
            builder: (context, reservationsSnapshot) {
              if (reservationsSnapshot.connectionState ==
                  ConnectionState.waiting) {
                return const Center(child: Text('Loading reservations...'));
              }

              final Map<String, Reservation> reservedTableMap = {
                for (var doc in reservationsSnapshot.data?.docs ?? [])
                  (Reservation.fromFirestore(doc).tableNumber.toString()):
                      Reservation.fromFirestore(doc),
              };

              return GridView.builder(
                padding: const EdgeInsets.all(16.0),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 7,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: tableCount,
                itemBuilder: (context, index) {
                  final tableNumber = (index + 1).toString();
                  final isOccupied = occupiedTableMap.containsKey(tableNumber);
                  final isReserved =
                      reservedTableMap.containsKey(tableNumber) && !isOccupied;

                  final orderDoc = occupiedTableMap[tableNumber];
                  final reservation = reservedTableMap[tableNumber];

                  Color buttonColor = Colors.green.shade600;
                  String? subtitle;
                  IconData statusIcon;

                  if (isOccupied) {
                    buttonColor = Colors.red.shade700;
                    subtitle =
                        (orderDoc?.data()
                            as Map<String, dynamic>?)?['customerName'] ??
                        orderDoc?['orderIdentifier']?.replaceAll('Table ', '');
                    statusIcon = Icons.people;
                  } else if (isReserved) {
                    buttonColor = Colors.amber.shade700;
                    subtitle = reservation?.customerName;
                    statusIcon = Icons.bookmark_added;
                  } else {
                    statusIcon = Icons.event_seat;
                  }

                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: buttonColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(4),
                    ),
                    onPressed: () {
                      if (isReserved && reservation != null) {
                        // If the table is reserved, show the check-in dialog
                        _showReservationCheckInDialog(context, reservation);
                      } else {
                        // Otherwise, go to the order page as before
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => OrderDashboardPage(
                              orderId: isOccupied ? orderDoc!.id : null,
                              tableNumber: isOccupied ? null : (index + 1),
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(statusIcon, size: 28),
                        const SizedBox(height: 4),
                        Text(
                          tableNumber,
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (subtitle != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 2.0),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                subtitle,
                                style: const TextStyle(fontSize: 10),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
