import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/network/dio_client.dart';
import '../../data/models/notification_item.dart';
import '../../data/notifications_repository.dart';

part 'notifications_provider.g.dart';

@riverpod
NotificationsRepository notificationsRepository(Ref ref) {
  return NotificationsRepository(ref.watch(dioProvider));
}

@riverpod
class NotificationsNotifier extends _$NotificationsNotifier {
  @override
  Future<NotificationListResult> build() {
    return ref.read(notificationsRepositoryProvider).list();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(notificationsRepositoryProvider).list(),
    );
  }

  Future<void> markRead(String notificationId) async {
    final current = state.valueOrNull;
    if (current == null) return;

    // Optimistic update so the tap feels instant.
    final updated = current.notifications
        .map((n) => n.notificationId == notificationId ? n.copyWith(isRead: true) : n)
        .toList();
    final wasUnread = current.notifications
        .firstWhere((n) => n.notificationId == notificationId)
        .isRead ==
        false;

    state = AsyncData(
      NotificationListResult(
        notifications: updated,
        totalCount: current.totalCount,
        unreadCount: wasUnread ? current.unreadCount - 1 : current.unreadCount,
      ),
    );

    try {
      await ref.read(notificationsRepositoryProvider).markRead(notificationId);
    } catch (_) {
      // Revert on failure by re-fetching from the server.
      await refresh();
    }
  }
}
