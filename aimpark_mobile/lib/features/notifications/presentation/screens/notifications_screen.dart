import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/notification_item.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Future<void> refresh() =>
        ref.read(notificationsNotifierProvider.notifier).refresh();

    return AppScreen.tab(
      body: AsyncView(
        value: ref.watch(notificationsNotifierProvider),
        onRefresh: refresh,
        errorTitle: "Couldn't load your alerts",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.notifications.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.notifications_off_rounded,
          title: 'No alerts yet',
          message: "We'll let you know when something needs your attention.",
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            AppSectionHeader(
              title: 'Alerts',
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              action: result.unreadCount > 0
                  ? AppStatusBadge(
                      label: '${result.unreadCount} new',
                      intent: StatusIntent.brand,
                    )
                  : null,
            ),
            for (final notification in result.notifications) ...[
              _NotificationTile(
                notification: notification,
                onTap: notification.isRead
                    ? null
                    : () => ref
                        .read(notificationsNotifierProvider.notifier)
                        .markRead(notification.notificationId),
              ),
              if (notification != result.notifications.last) const AppRowGap(),
            ],
          ],
        ),
      ),
    );
  }
}

/// Not an [AppListRow]: an alert's message is the content rather than a
/// subtitle, so it wraps to as many lines as it needs, and the whole card tints
/// while it is unread. The shared row would have to grow two flags that only
/// this screen ever sets.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationItem notification;

  /// Null once read — there is nothing left to do to it.
  final VoidCallback? onTap;

  /// Keys are the API's `NotificationType` names, lowercased. The previous
  /// cases ('policy', 'availability', 'security') matched none of them, so
  /// every notification fell through to the default icon.
  IconData get _icon => switch (notification.type.toLowerCase()) {
        'policyupdate' => Icons.rule_rounded,
        'parkingavailability' => Icons.local_parking_rounded,
        'violation' => Icons.gavel_rounded,
        'payment' => Icons.payments_rounded,
        'account' => Icons.verified_user_rounded,
        'incident' => Icons.report_rounded,
        'system' => Icons.info_rounded,
        _ => Icons.campaign_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final unread = !notification.isRead;
    final c = t.status.of(StatusIntents.notificationType(notification.type));

    return AppCard(
      onTap: onTap,
      // Unread alerts are tinted by their *kind*, so a violation notice is
      // visibly not the same thing as a parking-availability notice at a
      // glance. Read ones drop back to the ordinary card surface.
      color: unread ? c.bg : null,
      borderColor: unread ? c.border : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: c.fg, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.title, style: context.text.labelLarge),
                const SizedBox(height: 2),
                Text(notification.message, style: context.text.bodySmall),
                const SizedBox(height: 4),
                Text(
                  Formatters.relativeTime(notification.createdAt),
                  style: context.text.labelSmall,
                ),
              ],
            ),
          ),
          if (unread)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
              decoration: BoxDecoration(
                color: c.solid,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
