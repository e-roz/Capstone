class NotificationItem {
  const NotificationItem({
    required this.notificationId,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required this.isRead,
    this.targetRole,
    this.data = const {},
  });

  final String notificationId;
  final String title;
  final String message;
  final String type;
  final String? targetRole;
  final DateTime createdAt;
  final bool isRead;

  /// What it is about (`violationId`, `paymentId`, `incidentId`, `screen`),
  /// as the push carried it. Empty for announcements and for rows from before
  /// the server kept it.
  final Map<String, String> data;

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    return NotificationItem(
      notificationId: json['notificationId'] as String,
      title: json['title'] as String,
      message: json['message'] as String,
      type: json['type'] as String,
      targetRole: json['targetRole'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      isRead: json['isRead'] as bool,
      data: {
        for (final e in ((json['data'] as Map<String, dynamic>?) ?? {}).entries)
          e.key: e.value.toString(),
      },
    );
  }

  NotificationItem copyWith({bool? isRead}) {
    return NotificationItem(
      notificationId: notificationId,
      title: title,
      message: message,
      type: type,
      targetRole: targetRole,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      data: data,
    );
  }
}

class NotificationListResult {
  const NotificationListResult({
    required this.notifications,
    required this.totalCount,
    required this.unreadCount,
  });

  final List<NotificationItem> notifications;
  final int totalCount;
  final int unreadCount;

  factory NotificationListResult.fromJson(Map<String, dynamic> json) {
    return NotificationListResult(
      notifications: (json['notifications'] as List<dynamic>)
          .map((e) => NotificationItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalCount: json['totalCount'] as int,
      unreadCount: json['unreadCount'] as int,
    );
  }
}
