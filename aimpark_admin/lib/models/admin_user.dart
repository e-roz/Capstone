class AdminUser {
  final String userId;
  final String fullName;
  final String email;
  final String role;
  final String accountStatus;
  final String rfidStatus;

  /// Null when no card is held. Older API builds never send it.
  final String? rfidTagId;
  final bool isDeleted;
  final DateTime createdAt;

  const AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.rfidStatus,
    this.rfidTagId,
    required this.isDeleted,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
    userId: json['userId']?.toString() ?? '',
    fullName: json['fullName']?.toString() ?? '',
    email: json['email']?.toString() ?? '',
    role: json['role']?.toString() ?? '',
    accountStatus: json['accountStatus']?.toString() ?? '',
    rfidStatus: json['rfidStatus']?.toString() ?? '',
    rfidTagId: json['rfidTagId']?.toString(),
    isDeleted: (json['isDeleted'] as bool?) ?? false,
    createdAt: DateTime.parse(json['createdAt'].toString()),
  );

  /// The status the list shows. Archived is the separate IsDeleted flag on the
  /// API, not an AccountStatus, but to an admin it is just another state.
  String get displayStatus => isDeleted ? UserStatuses.archived : accountStatus;

  /// Staff accounts get a tag in the list; ordinary users do not need one.
  bool get isStaff => role == UserRoles.security || role == UserRoles.admin;
}

/// Account status values as the API sends them, plus the virtual `Archived`
/// filter value the list endpoint accepts.
abstract final class UserStatuses {
  static const active = 'Active';
  static const suspended = 'Suspended';
  static const revoked = 'Revoked';
  static const archived = 'Archived';
  static const pendingReview = 'PendingReview';
  static const rejected = 'Rejected';

  /// The words an admin reads. The list and the status filter both use this,
  /// so a pill can never say "PendingReview" while the filter says
  /// "Pending review".
  static String label(String status) => switch (status) {
    pendingReview => 'Pending review',
    _ => status,
  };

  /// Applicants, not accounts. They are reviewed on the Registrations screen.
  static bool isApplicant(String status) =>
      status == pendingReview || status == rejected;
}

abstract final class UserRoles {
  static const user = 'User';
  static const security = 'Security';
  static const admin = 'Admin';
}

class UserListPage {
  final List<AdminUser> users;
  final int totalCount;
  final int page;
  final int pageSize;

  const UserListPage({
    required this.users,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory UserListPage.fromJson(Map<String, dynamic> json) => UserListPage(
    users: (json['users'] as List<dynamic>? ?? [])
        .map((u) => AdminUser.fromJson(u as Map<String, dynamic>))
        .toList(),
    totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
    page: (json['page'] as num?)?.toInt() ?? 1,
    pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
  );
}
