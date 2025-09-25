import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../notification_provider.dart';
class NotificationCenterPage extends StatelessWidget {
  const NotificationCenterPage({super.key});

  void _handleNotificationTap(BuildContext context, AppNotification n) {
    // --- THIS IS THE TEST CODE ---
    print('--- Tapped on notification: ${n.title} ---');
    // -----------------------------

    context.read<NotificationProvider>().markSeen(n.id);

    switch (n.type) {
      case 'LOW_STOCK':
        context.push('/admin/inventory');
        break;
      case 'ORDER_READY':
        context.push('/all-orders');
        break;
      case 'REFUND_PROCESSED':
        context.push('/all-orders');
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<NotificationProvider>();
    final items = provider.items;

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.separated(
        itemCount: items.length,
        padding: const EdgeInsets.all(12),
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final n = items[i];
          final seen = n.isSeen(provider.uid);
          return ListTile(
            leading: Icon(
              n.severity == 'critical'
                  ? Icons.error
                  : n.severity == 'warn'
                  ? Icons.warning
                  : Icons.info,
              color: n.severity == 'critical'
                  ? Colors.red
                  : n.severity == 'warn'
                  ? Colors.orange
                  : null,
            ),
            title: Text(
              n.title,
              style: TextStyle(
                fontWeight: seen ? FontWeight.w400 : FontWeight.w700,
              ),
            ),
            subtitle: Text(
              n.message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Text(
              _fmt(n.createdAt),
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => _handleNotificationTap(context, n),
          );
        },
      ),
    );
  }

  String _fmt(DateTime dt) =>
      '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}
