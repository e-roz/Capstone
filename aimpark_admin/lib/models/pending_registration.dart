class PendingRegistration {
  final String userId;
  final String fullName;
  final String email;
  final DateTime createdAt;
  final DateTime updatedAt;

  const PendingRegistration({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PendingRegistration.fromJson(Map<String, dynamic> json) =>
      PendingRegistration(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}
