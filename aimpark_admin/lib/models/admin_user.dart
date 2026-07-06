class AdminUser {
  final String userId;
  final String fullName;
  final String email;
  final String accountStatus;
  final bool isDeleted;
  final DateTime createdAt;

  const AdminUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.accountStatus,
    required this.isDeleted,
    required this.createdAt,
  });

  factory AdminUser.fromJson(Map<String, dynamic> json) => AdminUser(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        accountStatus: json['accountStatus']?.toString() ?? '',
        isDeleted: (json['isDeleted'] as bool?) ?? false,
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
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
