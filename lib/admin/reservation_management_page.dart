import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:restaurant_models/restaurant_models.dart';
import 'package:table_calendar/table_calendar.dart';
class ReservationManagementPage extends StatefulWidget {
  const ReservationManagementPage({super.key});

  @override
  State<ReservationManagementPage> createState() =>
      _ReservationManagementPageState();
}

class _ReservationManagementPageState extends State<ReservationManagementPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.week;

  // --- 1. ฟังก์ชันสำหรับแสดง Dialog เพิ่ม/แก้ไข การจอง ---
  void _showAddReservationDialog() {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    final guestsController = TextEditingController();
    final tableController = TextEditingController();
    final notesController = TextEditingController();
    TimeOfDay? selectedTime;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Reservation'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Customer Name',
                    ),
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a name' : null,
                  ),
                  TextFormField(
                    controller: phoneController,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                    ),
                    keyboardType: TextInputType.phone,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a phone number' : null,
                  ),
                  TextFormField(
                    controller: guestsController,
                    decoration: const InputDecoration(
                      labelText: 'Number of Guests',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter number of guests' : null,
                  ),
                  TextFormField(
                    controller: tableController,
                    decoration: const InputDecoration(
                      labelText: 'Table Number',
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) =>
                        value!.isEmpty ? 'Please enter a table number' : null,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Reservation Time'),
                    trailing: TextButton(
                      onPressed: () async {
                        selectedTime = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                      },
                      child: const Text('Select Time'),
                    ),
                  ),
                  TextFormField(
                    controller: notesController,
                    decoration: const InputDecoration(
                      labelText: 'Notes (optional)',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate() && selectedTime != null) {
                  final reservationDateTime = DateTime(
                    _selectedDay.year,
                    _selectedDay.month,
                    _selectedDay.day,
                    selectedTime!.hour,
                    selectedTime!.minute,
                  );

                  FirebaseFirestore.instance.collection('reservations').add({
                    'customerName': nameController.text,
                    'phoneNumber': phoneController.text,
                    'numberOfGuests': int.parse(guestsController.text),
                    'tableNumber': int.parse(tableController.text),
                    'reservationTime': Timestamp.fromDate(reservationDateTime),
                    'notes': notesController.text,
                  });
                  Navigator.of(context).pop();
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select a reservation time.'),
                    ),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // --- 2. ฟังก์ชันสำหรับยืนยันการลบ ---
  void _deleteReservation(String reservationId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Deletion'),
        content: const Text(
          'Are you sure you want to delete this reservation?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              FirebaseFirestore.instance
                  .collection('reservations')
                  .doc(reservationId)
                  .delete();
              Navigator.of(context).pop();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Reservations'),
        backgroundColor: Colors.indigo,
      ),
      body: Column(
        children: [
          TableCalendar(
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2030, 12, 31),
            focusedDay: _focusedDay,
            calendarFormat: _calendarFormat,
            selectedDayPredicate: (day) {
              return isSameDay(_selectedDay, day);
            },
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onFormatChanged: (format) {
              if (_calendarFormat != format) {
                setState(() {
                  _calendarFormat = format;
                });
              }
            },
            onPageChanged: (focusedDay) {
              _focusedDay = focusedDay;
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Text(
              'Reservations for ${DateFormat('dd MMMM yyyy').format(_selectedDay)}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          Expanded(child: _buildReservationList()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed:
            _showAddReservationDialog, // <-- 3. เชื่อมปุ่มเข้ากับฟังก์ชัน
        tooltip: 'Add Reservation',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildReservationList() {
    final startOfDay = Timestamp.fromDate(
      DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day),
    );
    final endOfDay = Timestamp.fromDate(
      DateTime(
        _selectedDay.year,
        _selectedDay.month,
        _selectedDay.day,
        23,
        59,
        59,
      ),
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('reservations')
          .where('reservationTime', isGreaterThanOrEqualTo: startOfDay)
          .where('reservationTime', isLessThanOrEqualTo: endOfDay)
          .orderBy('reservationTime')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return const Center(child: Text('Error fetching reservations.'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(
            child: Text('No reservations for the selected date.'),
          );
        }

        final reservations = snapshot.data!.docs
            .map((doc) => Reservation.fromFirestore(doc))
            .toList();

        return ListView.builder(
          itemCount: reservations.length,
          itemBuilder: (context, index) {
            final reservation = reservations[index];
            return ListTile(
              leading: CircleAvatar(
                child: Text(reservation.tableNumber.toString()),
              ),
              title: Text(reservation.customerName),
              subtitle: Text(
                '${reservation.numberOfGuests} guests at ${DateFormat('HH:mm').format(reservation.reservationTime)}',
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: () => _deleteReservation(
                  reservation.id,
                ), // <-- 4. เชื่อมปุ่มเข้ากับฟังก์ชัน
              ),
            );
          },
        );
      },
    );
  }
}
