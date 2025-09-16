import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../notification_provider.dart';
import '../pages/notification_center_page.dart';

class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final count =
        context.select<NotificationProvider, int>((p) => p.unseenCount);

    return Stack(
      children: [
        IconButton(
          tooltip: 'การแจ้งเตือน',
          icon: const Icon(Icons.notifications),
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NotificationCenterPage()),
          ),
        ),
        if (count > 0)
          Positioned(
            right: 4,
            top: 6,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text('$count',
                  style: const TextStyle(color: Colors.white, fontSize: 11)),
            ),
          ),
      ],
    );
  }
}
