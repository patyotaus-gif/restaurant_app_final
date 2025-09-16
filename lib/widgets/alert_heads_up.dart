import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../notification_provider.dart';
import '../models/notification_model.dart';

class AlertHeadsUp extends StatefulWidget {
  const AlertHeadsUp({super.key});
  @override
  State<AlertHeadsUp> createState() => _AlertHeadsUpState();
}

class _AlertHeadsUpState extends State<AlertHeadsUp> {
  OverlayEntry? _entry;
  Timer? _timer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final latest = context.watch<NotificationProvider>().latestUnseen;
    if (latest != null) _show(latest);
  }

  void _handleNotificationTap(BuildContext context, AppNotification n) {
    // First, mark the notification as seen and remove the banner
    context.read<NotificationProvider>().markSeen(n.id);
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    // Then, navigate based on the notification type
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
        // Do nothing for unknown types
        break;
    }
  }

  void _show(AppNotification n) {
    _timer?.cancel();
    _entry?.remove();
    _entry = null;

    _entry = OverlayEntry(
      builder: (_) => Positioned(
        top: 40,
        left: 16,
        right: 16,
        child: _Banner(
          alert: n,
          onTap: () => _handleNotificationTap(context, n),
          onClose: () {
            context.read<NotificationProvider>().markSeen(n.id);
            _timer?.cancel();
            _entry?.remove();
            _entry = null;
          },
        ),
      ),
    );

    if (mounted) {
      Overlay.of(context).insert(_entry!);
      _timer = Timer(const Duration(seconds: 4), () {
        if (_entry != null && _entry!.mounted) {
          context.read<NotificationProvider>().markSeen(n.id);
          _entry?.remove();
          _entry = null;
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _entry?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.alert,
    required this.onTap,
    required this.onClose,
  });
  final AppNotification alert;
  final VoidCallback onTap;
  final VoidCallback onClose;

  Color _bg(BuildContext c) {
    switch (alert.severity) {
      case 'critical':
        return Colors.red.shade600;
      case 'warn':
        return Colors.orange.shade600;
      default:
        return Theme.of(c).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _bg(context),
      elevation: 6,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                alert.severity == 'critical'
                    ? Icons.error
                    : alert.severity == 'warn'
                    ? Icons.warning
                    : Icons.info,
                color: Colors.white,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      alert.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      alert.message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onClose,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
