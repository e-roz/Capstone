import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/notification.dart';
import '../providers/notifications_provider.dart';
import '../core/utils/responsive.dart';
import '../widgets/page_header.dart';

const _types = ['Announcement', 'PolicyUpdate', 'ParkingAvailability', 'System'];
const _roles = ['Admin', 'Security', 'User'];

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationListProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            PageHeader(
              title: 'Notifications',
              actions: [
                FilledButton.icon(
                  icon: const Icon(Icons.campaign, size: 16),
                  label: const Text('Broadcast'),
                  onPressed: () => _showBroadcast(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  tooltip: 'Refresh',
                  onPressed: () => ref.invalidate(notificationListProvider),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Failed to load notifications: $e')),
                data: (page) => Column(
                  children: [
                    Expanded(child: _NotificationList(page: page)),
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

  Future<void> _showBroadcast(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    String type = _types.first;
    String? targetRole;
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Broadcast Notification'),
          content: SizedBox(
            width: context.dialogWidth(400),
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Title', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: messageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        labelText: 'Message', border: OutlineInputBorder()),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Message is required' : null,
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(
                        labelText: 'Type', border: OutlineInputBorder()),
                    items: _types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String?>(
                    initialValue: targetRole,
                    decoration: const InputDecoration(
                        labelText: 'Target Role', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Roles')),
                      ..._roles.map((r) => DropdownMenuItem(value: r, child: Text(r))),
                    ],
                    onChanged: (v) => setState(() => targetRole = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Broadcast'),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true || !context.mounted) return;
    final msg = await ref.read(notificationActionsProvider.notifier).broadcast(
          title: titleCtrl.text.trim(),
          message: messageCtrl.text.trim(),
          type: type,
          targetRole: targetRole,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Notification broadcast.')));
    ref.invalidate(notificationListProvider);
  }
}

class _NotificationList extends StatelessWidget {
  const _NotificationList({required this.page});

  final NotificationListPage page;

  @override
  Widget build(BuildContext context) {
    if (page.notifications.isEmpty) {
      return const Center(child: Text('No notifications sent yet.'));
    }

    return ListView.separated(
      itemCount: page.notifications.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) => _NotificationCard(item: page.notifications[i]),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final NotificationItem item;

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
            Chip(
              label: Text(item.type, style: const TextStyle(fontSize: 12, color: Colors.white)),
              backgroundColor: Colors.blueGrey,
              padding: EdgeInsets.zero,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(item.message, style: const TextStyle(fontSize: 13)),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('Target: ${item.targetRole ?? 'All roles'}',
                        style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ),
                ],
              ),
            ),
            Text(
              DateFormat('MMM d, yyyy HH:mm').format(item.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _Pagination extends ConsumerWidget {
  const _Pagination({required this.page});

  final NotificationListPage page;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalPages = (page.totalCount / page.pageSize).ceil().clamp(1, 999999);
    final currentPage = page.page;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
            'Showing ${page.notifications.length} of ${page.totalCount} notifications • Page $currentPage of $totalPages'),
        const SizedBox(width: 16),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: currentPage > 1
              ? () => ref
                  .read(notificationsQueryNotifierProvider.notifier)
                  .setPage(currentPage - 1)
              : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: currentPage < totalPages
              ? () => ref
                  .read(notificationsQueryNotifierProvider.notifier)
                  .setPage(currentPage + 1)
              : null,
        ),
      ],
    );
  }
}
