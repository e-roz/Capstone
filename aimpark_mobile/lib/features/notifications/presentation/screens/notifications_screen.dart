import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/notification_item.dart';
import '../providers/notifications_provider.dart';

/// Everything the app has told the user, newest first, in day groups.
///
/// Called "Notifications" because that is what the row on Account that leads
/// here is called; it used to say "Alerts", so tapping one name landed on another.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(notificationsNotifierProvider.notifier);

    return AppScreen(
      body: AsyncView(
        value: ref.watch(notificationsNotifierProvider),
        onRefresh: notifier.refresh,
        errorTitle: "Couldn't load your notifications",
        loading: const Padding(
          padding: kScreenListPadding,
          child: AppRowSkeleton(),
        ),
        isEmpty: (result) => result.notifications.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.notifications_off_rounded,
          title: 'No notifications yet',
          message: "We'll let you know when something needs your attention.",
        ),
        data: (result) => ListView(
          padding: kScreenListPadding,
          children: [
            AppScreenTitle(
              title: 'Notifications',
              subtitle:
                  result.unreadCount > 0 ? '${result.unreadCount} unread' : null,
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              // The way out of a long unread list: one tap, rather than opening
              // them one at a time.
              action: result.unreadCount > 0
                  ? AppTextLink(
                      label: 'Mark all as read',
                      onTap: notifier.markAllRead,
                    )
                  : null,
            ),
            for (final day in _byDay(result.notifications)) ...[
              AppSectionHeader(title: day.label),
              for (final notification in day.items) ...[
                _NotificationTile(
                  notification: notification,
                  onTap: notification.isRead
                      ? null
                      : () => notifier.markRead(notification.notificationId),
                ),
                if (notification != day.items.last) const AppRowGap(),
              ],
              const SizedBox(height: AppSpacing.lg),
            ],
          ],
        ),
      ),
    );
  }
}

/// One day of notifications, under a heading like "Today · Oct 11".
class _Day {
  _Day(this.label) : items = [];

  final String label;
  final List<NotificationItem> items;
}

/// Splits [all], already newest first, into one group per calendar day.
List<_Day> _byDay(List<NotificationItem> all) {
  final days = <_Day>[];
  DateTime? current;

  for (final n in all) {
    final when = n.createdAt.toLocal();
    final key = DateTime(when.year, when.month, when.day);

    if (current != key) {
      current = key;
      final rel = Formatters.relativeDay(when);
      final isRelative = rel == 'Today' || rel == 'Yesterday';
      days.add(
        _Day(isRelative ? '$rel · ${Formatters.dateShort(when)}' : rel),
      );
    }
    days.last.items.add(n);
  }
  return days;
}

/// Not an [AppListRow]: a notification's message is the content rather than a
/// subtitle, so it wraps to as many lines as it needs.
///
/// Unread is a bold title and a thin coloured edge, not a tinted card. With a
/// couple of dozen unread, tinting every card made the whole screen one loud
/// block of colour and hid which ones were the new ones.
class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationItem notification;

  /// Null once read — there is nothing left to do to it.
  final VoidCallback? onTap;

  /// Keys are the API's `NotificationType` names, lowercased.
  IconData get _icon => switch (notification.type.toLowerCase()) {
        'policyupdate' => Icons.rule_rounded,
        'parkingavailability' => Icons.local_parking_rounded,
        'violation' => Icons.gavel_rounded,
        'payment' => Icons.payments_rounded,
        'account' => Icons.verified_user_rounded,
        'incident' => Icons.report_rounded,
        'parking' => Icons.directions_car_rounded,
        'reminder' => Icons.schedule_rounded,
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
      edgeColor: unread ? c.solid : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The kind of notification, in its own colour, so a violation notice
          // is visibly not a parking-availability one at a glance.
          Container(
            width: AppSizes.rowIcon,
            height: AppSizes.rowIcon,
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: Icon(_icon, color: c.fg, size: AppSizes.iconMd),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: context.text.labelLarge?.copyWith(
                    fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: context.text.bodySmall?.copyWith(
                    color: unread ? null : t.text.secondary,
                  ),
                ),
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
              decoration: BoxDecoration(color: c.solid, shape: BoxShape.circle),
            ),
        ],
      ),
    );
  }
}
