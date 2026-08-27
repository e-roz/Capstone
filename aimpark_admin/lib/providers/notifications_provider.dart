import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/constants/api_endpoints.dart';
import '../core/network/dio_client.dart';
import '../models/notification.dart';

part 'notifications_provider.g.dart';

class NotificationsQuery {
  final int page;
  final int pageSize;

  const NotificationsQuery({this.page = 1, this.pageSize = 20});

  NotificationsQuery copyWith({int? page, int? pageSize}) => NotificationsQuery(
        page: page ?? this.page,
        pageSize: pageSize ?? this.pageSize,
      );
}

@riverpod
class NotificationsQueryNotifier extends _$NotificationsQueryNotifier {
  @override
  NotificationsQuery build() => const NotificationsQuery();

  void setPage(int page) => state = state.copyWith(page: page);
}

/// What has been addressed to the signed-in staff account.
///
/// Distinct from [notificationList], which is the log of broadcasts an
/// administrator has *sent*. A guard needs the other direction - the spec calls
/// it "Receive Notifications" - and until this existed the panel could only
/// send, so a violation or an approval addressed to staff arrived nowhere they
/// could see it.
@riverpod
Future<NotificationListPage> inbox(Ref ref) async {
  final dio = ref.watch(dioProvider);
  final response = await dio.get(
    ApiEndpoints.myNotifications,
    queryParameters: {'page': 1, 'pageSize': 50},
  );
  return NotificationListPage.fromJson(response.data as Map<String, dynamic>);
}

/// Unread count for the sidebar badge.
@riverpod
Future<int> unreadInboxCount(Ref ref) async {
  final page = await ref.watch(inboxProvider.future);
  return page.unreadCount;
}

@riverpod
class InboxActions extends _$InboxActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> markRead(String notificationId) async {
    try {
      final dio = ref.read(dioProvider);
      await dio.post(ApiEndpoints.markNotificationRead(notificationId));
      ref.invalidate(inboxProvider);
      return null;
    } on DioException catch (e) {
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? 'Could not mark it read.';
      return e.message ?? 'Could not mark it read.';
    }
  }
}

@riverpod
Future<NotificationListPage> notificationList(Ref ref) async {
  final query = ref.watch(notificationsQueryNotifierProvider);
  final dio = ref.watch(dioProvider);

  final params = <String, dynamic>{
    'page': query.page,
    'pageSize': query.pageSize,
  };

  final response =
      await dio.get(ApiEndpoints.notifications, queryParameters: params);
  return NotificationListPage.fromJson(response.data as Map<String, dynamic>);
}

@riverpod
class NotificationActions extends _$NotificationActions {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<String?> broadcast({
    required String title,
    required String message,
    required String type,
    String? targetRole,
  }) async {
    state = const AsyncLoading();
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(ApiEndpoints.notifications, data: {
        'title': title,
        'message': message,
        'type': type,
        'targetRole': targetRole,
      });
      state = const AsyncData(null);
      return (res.data as Map<String, dynamic>)['message']?.toString();
    } on DioException catch (e) {
      state = const AsyncData(null);
      final data = e.response?.data;
      if (data is Map) return data['message']?.toString() ?? e.message ?? 'Error';
      return e.message ?? 'Unknown error';
    }
  }
}
