// lib/notification_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/notification_model.dart';
import 'notifications_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationsRepository repo;
  String uid; // <-- ทำให้ public เพื่อให้ update ได้
  StreamSubscription<List<AppNotification>>? _sub;
  List<AppNotification> _items = [];
  AppNotification? _latestUnseen;

  NotificationProvider({required this.repo, required this.uid}) {
    _listenToStream(); // <-- เรียกใช้ฟังก์ชัน stream
  }

  // --- 1. สร้างฟังก์ชันสำหรับเริ่มฟัง Stream ---
  void _listenToStream() {
    _sub?.cancel(); // ยกเลิกของเก่าก่อนเสมอ
    _sub = repo.watch().listen((list) {
      _items = list;
      _latestUnseen = list.firstWhere(
        (n) => !n.isSeen(uid),
        // แก้ไข: ให้คืนค่า null ถ้าไม่เจอเลย เพื่อป้องกัน error
        orElse: () => null as AppNotification,
      );
      notifyListeners();
    });
  }

  // --- 2. เพิ่มฟังก์ชัน updateUid ---
  void updateUid(String newUid) {
    if (uid == newUid) return; // ถ้า uid เหมือนเดิม ไม่ต้องทำอะไร
    uid = newUid;
    _listenToStream(); // เริ่มฟัง stream ใหม่ด้วย uid ใหม่
    print('NotificationProvider UID updated to: $uid');
  }
  // --------------------------------

  List<AppNotification> get items => _items;
  AppNotification? get latestUnseen => _latestUnseen;
  int get unseenCount => _items.where((n) => !n.isSeen(uid)).length;

  Future<void> markSeen(String id) => repo.markSeen(id, uid);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
