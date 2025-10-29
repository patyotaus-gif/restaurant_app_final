import 'package:flutter/material.dart';

class AppBlockedScreen extends StatelessWidget {
  const AppBlockedScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final effectiveMessage = message ??
        'This version of the app has been disabled. Please update to continue.';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            elevation: 6,
            margin: const EdgeInsets.symmetric(horizontal: 24),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 36,
                      ),
                      const SizedBox(width: 12),
                      Flexible(
                        child: Text(
                          'Update Required',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: theme.colorScheme.error,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    effectiveMessage,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    icon: const Icon(Icons.system_update),
                    label: const Text('Check for updates'),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please update the application from your app store or deployment channel.',
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
