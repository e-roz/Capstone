/// One thing that happened to a user account — a login, a failed login, a
/// registration, a status change.
class UserActivityLogEntry {
  final String id;
  final String? userId;
  final String emailAtTime;

  /// Resolved server-side; falls back to the stored email when the account is
  /// gone, or never existed in the case of a failed login.
  final String userName;

  final String activity;
  final String? detail;
  final String? ipAddress;
  final DateTime createdAt;

  const UserActivityLogEntry({
    required this.id,
    required this.userId,
    required this.emailAtTime,
    required this.userName,
    required this.activity,
    required this.detail,
    required this.ipAddress,
    required this.createdAt,
  });

  factory UserActivityLogEntry.fromJson(Map<String, dynamic> json) =>
      UserActivityLogEntry(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString(),
        emailAtTime: json['emailAtTime']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        activity: json['activity']?.toString() ?? '',
        detail: json['detail']?.toString(),
        ipAddress: json['ipAddress']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class UserActivityLogPage {
  final List<UserActivityLogEntry> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const UserActivityLogPage({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory UserActivityLogPage.fromJson(Map<String, dynamic> json) =>
      UserActivityLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => UserActivityLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

/// An unhandled server failure, as captured by the global exception handler.
class SystemErrorLogEntry {
  final String id;
  final String errorType;
  final String message;
  final String? stackTrace;
  final String? path;
  final int statusCode;

  /// Matches the `traceId` the caller was shown, so a tester's screenshot can
  /// be tied to this row without guessing from timestamps.
  final String? traceId;

  final DateTime createdAt;

  const SystemErrorLogEntry({
    required this.id,
    required this.errorType,
    required this.message,
    required this.stackTrace,
    required this.path,
    required this.statusCode,
    required this.traceId,
    required this.createdAt,
  });

  factory SystemErrorLogEntry.fromJson(Map<String, dynamic> json) =>
      SystemErrorLogEntry(
        id: json['id']?.toString() ?? '',
        errorType: json['errorType']?.toString() ?? '',
        message: json['message']?.toString() ?? '',
        stackTrace: json['stackTrace']?.toString(),
        path: json['path']?.toString(),
        statusCode: (json['statusCode'] as num?)?.toInt() ?? 0,
        traceId: json['traceId']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class SystemErrorLogPage {
  final List<SystemErrorLogEntry> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const SystemErrorLogPage({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory SystemErrorLogPage.fromJson(Map<String, dynamic> json) =>
      SystemErrorLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => SystemErrorLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
