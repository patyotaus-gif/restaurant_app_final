import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
class UnauthorizedPage extends StatelessWidget {
  const UnauthorizedPage({super.key, this.attemptedRoute});

  final String? attemptedRoute;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Unauthorized'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.lock_outline,
                size: 72,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'คุณไม่มีสิทธิ์เข้าถึงหน้านี้',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                attemptedRoute == null
                    ? 'โปรดติดต่อผู้ดูแลระบบเพื่อขอสิทธิ์เพิ่มเติม'
                    : 'เส้นทาง "${attemptedRoute!}" ต้องการสิทธิ์เพิ่มเติม',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  context.go('/');
                },
                icon: const Icon(Icons.home),
                label: const Text('กลับไปหน้าแรก'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
