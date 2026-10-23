/// One account a bulk archive would take, or has taken.
class BulkArchiveUser {
  final String userId;
  final String fullName;
  final String email;
  final String affiliation;
  final bool hasCard;
  final DateTime lastActiveAt;

  const BulkArchiveUser({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.affiliation,
    required this.hasCard,
    required this.lastActiveAt,
  });

  factory BulkArchiveUser.fromJson(Map<String, dynamic> json) =>
      BulkArchiveUser(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        affiliation: json['affiliation']?.toString() ?? '',
        hasCard: json['hasCard'] == true,
        lastActiveAt: DateTime.parse(json['lastActiveAt'].toString()),
      );
}

/// An account the sweep leaves alone, and why.
class BulkArchiveSkip {
  final String fullName;
  final String reason;

  const BulkArchiveSkip({required this.fullName, required this.reason});

  factory BulkArchiveSkip.fromJson(Map<String, dynamic> json) =>
      BulkArchiveSkip(
        fullName: json['fullName']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
      );
}

/// The answer to a bulk archive: a preview, or the real run.
class BulkArchiveResult {
  final List<BulkArchiveUser> users;
  final List<BulkArchiveSkip> skipped;
  final int cardsRevoked;

  const BulkArchiveResult({
    required this.users,
    required this.skipped,
    required this.cardsRevoked,
  });

  factory BulkArchiveResult.fromJson(Map<String, dynamic> json) =>
      BulkArchiveResult(
        users: [
          for (final u in json['users'] as List<dynamic>? ?? const [])
            BulkArchiveUser.fromJson(u as Map<String, dynamic>),
        ],
        skipped: [
          for (final s in json['skipped'] as List<dynamic>? ?? const [])
            BulkArchiveSkip.fromJson(s as Map<String, dynamic>),
        ],
        cardsRevoked: (json['cardsRevoked'] as num?)?.toInt() ?? 0,
      );
}
