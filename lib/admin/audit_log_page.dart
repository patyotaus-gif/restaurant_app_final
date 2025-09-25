import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:restaurant_models/restaurant_models.dart';

import '../auth_service.dart';
import '../services/audit_log_service.dart';
import '../store_provider.dart';
class AuditLogPage extends StatelessWidget {
  const AuditLogPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final storeProvider = context.watch<StoreProvider>();
    final auditLogService = context.read<AuditLogService>();

    if (!authService.hasPermission(Permission.viewAuditLogs)) {
      return Scaffold(
        appBar: AppBar(title: const Text('Audit Logs')),
        body: const Center(
          child: Text('You do not have permission to view audit logs.'),
        ),
      );
    }

    final Store? selectedStore = storeProvider.activeStore;
    final tenantId = selectedStore?.tenantId;

    return Scaffold(
      appBar: AppBar(title: const Text('Audit Trail')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.store_outlined),
                const SizedBox(width: 12),
                Text(selectedStore?.name ?? 'All Stores'),
                const Spacer(),
                IconButton(
                  onPressed: () => storeProvider.refreshRoleOverrides(),
                  icon: const Icon(Icons.policy),
                  tooltip: 'Refresh permissions',
                ),
              ],
            ),
          ),
          Expanded(
            child: tenantId == null
                ? const Center(
                    child: Text('Select a store to view tenant audit logs.'),
                  )
                : StreamBuilder<List<AuditLogEntry>>(
                    stream: auditLogService.watchLogs(
                      tenantId: tenantId,
                      storeId: selectedStore?.id,
                    ),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (snapshot.hasError) {
                        return Center(
                          child: Text(
                            'Failed to load audit logs: ${snapshot.error}',
                          ),
                        );
                      }
                      final logs = snapshot.data ?? [];
                      if (logs.isEmpty) {
                        return const Center(
                          child: Text('No audit activity found.'),
                        );
                      }
                      return ListView.builder(
                        itemCount: logs.length,
                        itemBuilder: (context, index) {
                          final log = logs[index];
                          return ListTile(
                            leading: const Icon(Icons.event_note_outlined),
                            title: Text(log.description),
                            subtitle: Text(
                              '${log.type.toUpperCase()} • ${log.timestamp.toLocal()} • ${log.actorId}',
                            ),
                            trailing: log.storeId != null
                                ? Chip(label: Text(log.storeId!))
                                : null,
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
