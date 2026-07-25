class AuditLogEntry {
  final String id;
  final String adminUserId;
  final String adminName;
  final String targetUserId;
  final String targetName;
  final String action;
  final String? oldValue;
  final String? newValue;
  final String? reason;
  final DateTime createdAt;

  const AuditLogEntry({
    required this.id,
    required this.adminUserId,
    required this.adminName,
    required this.targetUserId,
    required this.targetName,
    required this.action,
    this.oldValue,
    this.newValue,
    this.reason,
    required this.createdAt,
  });

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id']?.toString() ?? '',
        adminUserId: json['adminUserId']?.toString() ?? '',
        adminName: json['adminName']?.toString() ?? '',
        targetUserId: json['targetUserId']?.toString() ?? '',
        targetName: json['targetName']?.toString() ?? '',
        action: json['action']?.toString() ?? '',
        oldValue: json['oldValue']?.toString(),
        newValue: json['newValue']?.toString(),
        reason: json['reason']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class AuditLogPage {
  final List<AuditLogEntry> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const AuditLogPage({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory AuditLogPage.fromJson(Map<String, dynamic> json) => AuditLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => AuditLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
