class MyProfile {
  const MyProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.createdAt,
    this.phoneNumber,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String role;
  final String accountStatus;
  final DateTime createdAt;

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String,
      accountStatus: json['accountStatus'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

class AccessStatus {
  const AccessStatus({
    required this.rfidStatus,
    required this.accountStatus,
    this.rfidTagId,
  });

  final String? rfidTagId;
  final String rfidStatus;
  final String accountStatus;

  factory AccessStatus.fromJson(Map<String, dynamic> json) {
    return AccessStatus(
      rfidTagId: json['rfidTagId'] as String?,
      rfidStatus: json['rfidStatus'] as String,
      accountStatus: json['accountStatus'] as String,
    );
  }
}
