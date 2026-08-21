import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_state_views.dart';
import '../../data/models/notification_item.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notificationsAsync = ref.watch(notificationsNotifierProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPage,
      body: SafeArea(
        child: notificationsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppErrorState(
            title: "Couldn't load your alerts",
            onRetry: () => ref.read(notificationsNotifierProvider.notifier).refresh(),
          ),
          data: (result) {
            if (result.notifications.isEmpty) {
              return const AppEmptyState(
                icon: Icons.notifications_off_rounded,
                title: 'No alerts yet',
                message: "We'll let you know when something needs your attention.",
              );
            }
            return RefreshIndicator(
              onRefresh: () => ref.read(notificationsNotifierProvider.notifier).refresh(),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.xl,
                ),
                children: [
                  _Header(unreadCount: result.unreadCount),
                  const SizedBox(height: AppSpacing.lg),
                  for (final notification in result.notifications) ...[
                    _NotificationTile(
                      notification: notification,
                      onTap: notification.isRead
                          ? null
                          : () => ref
                              .read(notificationsNotifierProvider.notifier)
                              .markRead(notification.notificationId),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.unreadCount});
  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Alerts', style: AppTextStyles.h2),
        if (unreadCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandSubtle,
              borderRadius: BorderRadius.circular(AppRadius.full),
            ),
            child: Text(
              '$unreadCount new',
              style: AppTextStyles.labelSmall.copyWith(color: AppColors.brandPressed),
            ),
          ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final NotificationItem notification;
  final VoidCallback? onTap;

  /// Keys are the API's `NotificationType` names, lowercased. The previous
  /// cases ('policy', 'availability', 'security') matched none of them, so
  /// every notification fell through to the default icon.
  IconData get _icon {
    switch (notification.type.toLowerCase()) {
      case 'policyupdate':
        return Icons.rule_rounded;
      case 'parkingavailability':
        return Icons.local_parking_rounded;
      case 'violation':
        return Icons.gavel_rounded;
      case 'payment':
        return Icons.payments_rounded;
      case 'account':
        return Icons.verified_user_rounded;
      case 'system':
        return Icons.info_rounded;
      default:
        return Icons.campaign_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      color: notification.isRead ? AppColors.bgSurface : AppColors.brandSubtle,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, color: AppColors.brandPressed, size: 22),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(notification.message, style: AppTextStyles.bodySmall),
                const SizedBox(height: 4),
                Text(
                  Formatters.relativeTime(notification.createdAt),
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(top: 4, left: AppSpacing.sm),
              decoration: const BoxDecoration(
                color: AppColors.brandDefault,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
