import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerApprovalDialog extends StatefulWidget {
  final Function onApproved;

  const ManagerApprovalDialog({super.key, required this.onApproved});

  @override
  State<ManagerApprovalDialog> createState() => _ManagerApprovalDialogState();
}

class _ManagerApprovalDialogState extends State<ManagerApprovalDialog> {
  final _pinController = TextEditingController();
  String? _errorMessage;
  bool _isLoading = false; // <-- 1. เพิ่ม State สำหรับ Loading

  // --- 2. ปรับปรุงฟังก์ชันนี้ทั้งหมด ---
  Future<void> _verifyPin() async {
    if (_pinController.text.isEmpty) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final enteredPin = _pinController.text;

      // ค้นหาพนักงานที่มี PIN ตรงกัน และมีตำแหน่งเป็น Manager หรือ Owner
      final querySnapshot = await FirebaseFirestore.instance
          .collection('employees')
          .where('pin', isEqualTo: enteredPin)
          .where('role', whereIn: ['Manager', 'Owner'])
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // ถ้าเจอพนักงานที่ตรงเงื่อนไข
        if (mounted) context.pop(true);
        widget.onApproved();
      } else {
        // ถ้าไม่เจอ หรือ PIN ถูกแต่ตำแหน่งไม่ใช่
        setState(() {
          _errorMessage = 'Invalid PIN or insufficient permissions.';
        });
        _pinController.clear();
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'An error occurred. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  // ------------------------------------

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Manager Approval Required'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please enter Manager or Owner PIN to proceed.'),
          const SizedBox(height: 20),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'PIN Code',
              errorText: _errorMessage,
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => _verifyPin(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => context.pop(false),
          child: const Text('Cancel'),
        ),
        // --- 3. อัปเดตปุ่มให้แสดงสถานะ Loading ---
        ElevatedButton(
          onPressed: _isLoading ? null : _verifyPin,
          child: _isLoading
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Approve'),
        ),
        // --------------------------------------
      ],
    );
  }
}
