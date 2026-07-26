class NotificationItem {
  final String notificationId;
  final String title;
  final String message;
  final String type;
  final String? targetRole;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItem({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.targetRole,
    required this.createdAt,
    required this.isRead,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) =>
      NotificationItem(
        notificationId: json['notificationId']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        type: json['type']?.toString() ?? '',
        targetRole: json['targetRole']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
        isRead: (json['isRead'] as bool?) ?? false,
      );
}

class NotificationListPage {
  final List<NotificationItem> notifications;
  final int totalCount;
  final int page;
  final int pageSize;
  final int unreadCount;

  const NotificationListPage({
    required this.notifications,
    required this.totalCount,
    required this.page,
    required this.pageSize,
    required this.unreadCount,
  });

  factory NotificationListPage.fromJson(Map<String, dynamic> json) =>
      NotificationListPage(
        notifications: (json['notifications'] as List<dynamic>? ?? [])
            .map((n) => NotificationItem.fromJson(n as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
        unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      );
}
