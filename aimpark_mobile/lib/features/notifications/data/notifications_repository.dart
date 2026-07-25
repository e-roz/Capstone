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

  Future<void> markRead(String notificationId) {
    return _dio.post(ApiEndpoints.notificationRead(notificationId));
  }
}
