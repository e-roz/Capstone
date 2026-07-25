import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/audit_log_entry.dart';
import '../providers/audit_logs_provider.dart';

const _actions = [
  'Suspend',
  'Unsuspend',
  'Archive',
  'Restore',
  'Approve',
  'Reject',
  'ResetReapply',
  'ResetStep',
];

class AuditLogScreen extends ConsumerWidget {
  const AuditLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(auditLogsQueryNotifierProvider);
    final async = ref.watch(auditLogsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Audit Log',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                DropdownButton<String?>(
                  value: query.action,
                  hint: const Text('All Actions'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Actions')),
                    ..._actions.map(
                        (a) => DropdownMenuItem(value: a, child: Text(a))),
                  ],
                  onChanged: (v) => ref
                      .read(auditLogsQueryNotifierProvider.notifier)
                      .setAction(v),
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(auditLogsProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load audit log: $e')),
                data: (page) => Column(
                  children: [
                    Expanded(child: _LogList(page: page)),
                    const SizedBox(height: 12),
                    _Pagination(page: page),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LogList extends StatelessWidget {
  const _LogList({required this.page});

  final AuditLogPage page;

  @override
  Widget build(BuildContext context) {
    if (page.logs.isEmpty) {
      return const Center(
          child: Text('No admin actions recorded yet.', style: TextStyle(fontSize: 16)));
    }

    return ListView.separated(
      itemCount: page.logs.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _LogCard(entry: page.logs[i]),
    );
  }
}

class _LogCard extends StatelessWidget {
  const _LogCard({required this.entry});

  final AuditLogEntry entry;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _ActionChip(action: entry.action),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.adminName} → ${entry.targetName}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (entry.oldValue != null || entry.newValue != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${entry.oldValue ?? '—'}  →  ${entry.newValue ?? '—'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54),
                      ),
                    ),
                  if (entry.reason != null && entry.reason!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('Reason: ${entry.reason}',
                          style: const TextStyle(fontSize: 12, color: Colors.black87)),
                    ),
                ],
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(entry.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.action});

  final String action;

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (action) {
      case 'Approve':
      case 'Unsuspend':
      case 'Restore':
        color = Colors.green;
        break;
      case 'Reject':
      case 'Suspend':
      case 'Archive':
        color = Colors.red;
        break;
      default:
        color = Colors.blueGrey;
    }
    return Chip(
      label: Text(action, style: const TextStyle(fontSize: 12, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page});

  final AuditLogPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(1, 999999);
    final currentPage = page.page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            'Showing ${page.logs.length} of ${page.totalCount} actions • Page $currentPage of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => ref
                  .read(auditLogsQueryNotifierProvider.notifier)
                  .setPage(currentPage - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => ref
                  .read(auditLogsQueryNotifierProvider.notifier)
                  .setPage(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
