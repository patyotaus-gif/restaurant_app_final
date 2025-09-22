// lib/notification_provider.dart

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'models/notification_model.dart';
import 'notifications_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationsRepository repo;
  String uid; // <-- ทำให้ public เพื่อให้ update ได้
  String? _tenantId;
  StreamSubscription<List<AppNotification>>? _sub;
  List<AppNotification> _items = [];
  AppNotification? _latestUnseen;

  NotificationProvider({
    required this.repo,
    required this.uid,
    String? tenantId,
  }) : _tenantId = tenantId {
    _listenToStream(); // <-- เรียกใช้ฟังก์ชัน stream
  }

  // --- 1. สร้างฟังก์ชันสำหรับเริ่มฟัง Stream ---
  void _listenToStream() {
    _sub?.cancel(); // ยกเลิกของเก่าก่อนเสมอ
    final tenantId = _tenantId;
    if (tenantId == null) {
      _items = [];
      _latestUnseen = null;
      notifyListeners();
      return;
    }
    _sub = repo.watch(tenantId: tenantId).listen((list) {
      _items = list;
      AppNotification? firstUnseen;
      for (final notification in list) {
        if (!notification.isSeen(uid)) {
          firstUnseen = notification;
          break;
        }
      }
      _latestUnseen = firstUnseen;
      notifyListeners();
    });
  }

  // --- 2. เพิ่มฟังก์ชันอัปเดตคอนเท็กซ์ ---
  void updateContext({required String uid, String? tenantId}) {
    final hasUidChanged = this.uid != uid;
    final hasTenantChanged = _tenantId != tenantId;
    if (!hasUidChanged && !hasTenantChanged) {
      return;
    }
    this.uid = uid;
    _tenantId = tenantId;
    _listenToStream(); // เริ่มฟัง stream ใหม่ด้วย context ใหม่
    if (kDebugMode) {
      print(
        'Notification context updated -> uid: ${this.uid}, tenant: $_tenantId',
      );
    }
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
