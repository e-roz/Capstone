import 'package:dio/dio.dart';

import '../../../core/network/api_endpoints.dart';
import 'models/notification_item.dart';

class NotificationsRepository {
  NotificationsRepository(this._dio);

  final Dio _dio;

  Future<NotificationListResult> list({int page = 1, int pageSize = 20}) async {
    final response = await _dio.get(
      ApiEndpoints.notifications,
      queryParameters: {'page': page, 'pageSize': pageSize},
    );
    return NotificationListResult.fromJson(response.data as Map<String, dynamic>);
  }

  /// Marks everything as read in one call. One request per row is no way to
  /// clear a list that can run to dozens.
  Future<void> markAllRead() {
    return _dio.post(ApiEndpoints.notificationsReadAll);
  }

  Future<void> markRead(String notificationId) {
    return _dio.post(ApiEndpoints.notificationRead(notificationId));
  }

  Future<void> registerDeviceToken(String token, String platform) {
    return _dio.post(
      ApiEndpoints.deviceToken,
      data: {'token': token, 'platform': platform},
    );
  }

  Future<void> unregisterDeviceToken(String token) {
    return _dio.delete(ApiEndpoints.deviceToken, data: {'token': token});
  }
}
