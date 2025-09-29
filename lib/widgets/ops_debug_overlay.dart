import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/ops_observability_service.dart';
import '../services/sync_queue_service.dart';
import 'responsive/responsive_tokens.dart';
class OpsDebugOverlayHost extends StatelessWidget {
  const OpsDebugOverlayHost({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        const _OpsDebugOverlay(),
      ],
    );
  }
}

class _OpsDebugOverlay extends StatelessWidget {
  const _OpsDebugOverlay();

  Color _levelColor(OpsLogLevel level, ThemeData theme) {
    switch (level) {
      case OpsLogLevel.debug:
        return theme.colorScheme.secondary;
      case OpsLogLevel.info:
        return theme.colorScheme.primary;
      case OpsLogLevel.warning:
        return Colors.orange;
      case OpsLogLevel.error:
        return theme.colorScheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OpsObservabilityService>(
      builder: (context, ops, child) {
        final theme = Theme.of(context);
        final handle = Align(
          alignment: Alignment.bottomRight,
          child: SafeArea(
            minimum: const EdgeInsets.all(12),
            child: FloatingActionButton.small(
              heroTag: '_ops_debug_toggle',
              onPressed: ops.toggleOverlay,
              child: Icon(
                ops.overlayVisible ? Icons.bug_report : Icons.bug_report_outlined,
              ),
            ),
          ),
        );

        if (!ops.overlayVisible) {
          return IgnorePointer(ignoring: false, child: handle);
        }

        final tokens = ResponsiveTokens.of(context);

        return Stack(
          children: [
            handle,
            Align(
              alignment: Alignment.bottomRight,
              child: SafeArea(
                minimum: ResponsiveTokens.edgeInsetsSmall,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: tokens.overlayWidth,
                    maxHeight: math.max(240, MediaQuery.sizeOf(context).height * 0.45),
                  ),
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(tokens.radiusMedium),
                    clipBehavior: Clip.antiAlias,
                    color: theme.colorScheme.surface,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          color: theme.colorScheme.primaryContainer,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.monitor_heart),
                              const SizedBox(width: 8),
                              const Expanded(
                                child: Text(
                                  'Ops Debug Console',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                              Switch(
                                value: ops.remoteLoggingEnabled,
                                onChanged: (value) =>
                                    ops.remoteLoggingEnabled = value,
                              ),
                              const SizedBox(width: 4),
                              const Text('Remote'),
                              IconButton(
                                tooltip: 'Rotate queue key',
                                icon: const Icon(Icons.vpn_key),
                                onPressed: () async {
                                  final queueService =
                                      context.read<SyncQueueService>();
                                  await queueService.rotateEncryptionKey();
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: ops.hideOverlay,
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: ops.entries.length,
                            itemBuilder: (context, index) {
                              final entry = ops.entries[index];
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    border: Border(
                                      left: BorderSide(
                                        color: _levelColor(entry.level, theme),
                                        width: 4,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.only(left: 12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '[${entry.level.name.toUpperCase()}] '
                                          '${entry.timestamp.toIso8601String()}',
                                          style: theme.textTheme.labelSmall,
                                        ),
                                        const SizedBox(height: 4),
                                        Text(entry.message),
                                        if (entry.error != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.error!,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(color: theme.colorScheme.error),
                                          ),
                                        ],
                                        if (entry.context != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.context!.toString(),
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                        if (entry.stackTrace != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            entry.stackTrace!,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
