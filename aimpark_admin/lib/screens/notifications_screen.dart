import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/notification.dart';
import '../providers/notifications_provider.dart';
import '../theme/theme.dart';
import '../widgets/ui/ui.dart';

const _types = ['Announcement', 'PolicyUpdate', 'ParkingAvailability', 'System'];
const _roles = ['Admin', 'Security', 'User'];

/// Human wording for the API's enum names — `ParkingAvailability` is a value,
/// not a phrase, and it should not be what an administrator reads.
const _typeLabels = <String, String>{
  'Announcement': 'Announcement',
  'PolicyUpdate': 'Policy update',
  'ParkingAvailability': 'Parking availability',
  'System': 'System',
};

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppPage(
      title: 'Notifications',
      subtitle: 'Announcements and policy updates sent out to users.',
      actions: [
        FilledButton.icon(
          icon: const Icon(Icons.campaign_outlined, size: AppSizes.iconSm),
          label: const Text('Broadcast'),
          onPressed: () => _showBroadcast(context, ref),
        ),
        IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh',
          onPressed: () => ref.invalidate(notificationListProvider),
        ),
      ],
      body: AsyncView(
        value: ref.watch(notificationListProvider),
        onRetry: () => ref.invalidate(notificationListProvider),
        isEmpty: (page) => page.notifications.isEmpty,
        empty: AppEmptyState(
          icon: Icons.campaign_outlined,
          title: 'Nothing sent yet',
          message:
              'Broadcasts you send to students and security staff are listed '
              'here, most recent first.',
          action: FilledButton.icon(
            icon: const Icon(Icons.campaign_outlined, size: AppSizes.iconSm),
            label: const Text('Broadcast'),
            onPressed: () => _showBroadcast(context, ref),
          ),
        ),
        data: (page) => Column(
          children: [
            Expanded(
              child: ListView.separated(
                itemCount: page.notifications.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.gutter),
                itemBuilder: (context, i) =>
                    _NotificationCard(item: page.notifications[i]),
              ),
            ),
            const SizedBox(height: AppSpacing.gutter),
            AppPagination(
              page: page.page,
              pageSize: page.pageSize,
              total: page.totalCount,
              itemLabel: 'notifications',
              onPage: ref
                  .read(notificationsQueryNotifierProvider.notifier)
                  .setPage,
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
                  const AppRequiredNote(),
                  TextFormField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        label: AppFieldLabel('Title', isRequired: true)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Title is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  TextFormField(
                    controller: messageCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                        label: AppFieldLabel('Message', isRequired: true)),
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'Message is required' : null,
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  DropdownButtonFormField<String>(
                    initialValue: type,
                    decoration: const InputDecoration(labelText: 'Type'),
                    items: _types
                        .map((t) => DropdownMenuItem(
                            value: t, child: Text(_typeLabels[t] ?? t)))
                        .toList(),
                    onChanged: (v) => setState(() => type = v!),
                  ),
                  const SizedBox(height: AppSpacing.x3),
                  DropdownButtonFormField<String?>(
                    initialValue: targetRole,
                    decoration: const InputDecoration(labelText: 'Target Role'),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('All Roles')),
                      ..._roles.map(
                          (r) => DropdownMenuItem(value: r, child: Text(r))),
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

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({required this.item});

  final NotificationItem item;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPill.of(
            _typeLabels[item.type] ?? item.type,
            intent: StatusIntents.notificationType(item.type),
            dense: true,
          ),
          const SizedBox(width: AppSpacing.x4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title, style: text.titleSmall),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                  child: Text(item.message, style: text.bodySmall),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.x2),
                  child: Text(
                    'Sent to ${item.targetRole ?? 'all roles'}',
                    style: text.labelSmall?.copyWith(color: t.text.tertiary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Text(
            DateFormat('MMM d, yyyy HH:mm').format(item.createdAt.toLocal()),
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
      ),
    );
  }
}
