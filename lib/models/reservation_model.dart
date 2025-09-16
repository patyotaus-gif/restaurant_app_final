import 'package:cloud_firestore/cloud_firestore.dart';

class Reservation {
  final String id;
  final String customerName;
  final String phoneNumber;
  final int numberOfGuests;
  final int tableNumber;
  final DateTime reservationTime;
  final String notes;

  Reservation({
    required this.id,
    required this.customerName,
    required this.phoneNumber,
    required this.numberOfGuests,
    required this.tableNumber,
    required this.reservationTime,
    required this.notes,
  });

  factory Reservation.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Reservation(
      id: doc.id,
      customerName: data['customerName'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      numberOfGuests: data['numberOfGuests'] ?? 0,
      tableNumber: data['tableNumber'] ?? 0,
      reservationTime: (data['reservationTime'] as Timestamp).toDate(),
      notes: data['notes'] ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'customerName': customerName,
      'phoneNumber': phoneNumber,
      'numberOfGuests': numberOfGuests,
      'tableNumber': tableNumber,
      'reservationTime': Timestamp.fromDate(reservationTime),
      'notes': notes,
    };
  }
}
