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
  final String userId;
  final String fullName;
  final String reason;

  const BulkArchiveSkip({required this.userId, required this.fullName, required this.reason});

  factory BulkArchiveSkip.fromJson(Map<String, dynamic> json) =>
      BulkArchiveSkip(
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
      );
}

/// The newest real bulk archive, plus a fresh check of the people it left
/// alone: [ready] is a preview where `users` are now clear to archive and
/// `skipped` still are not.
class BulkArchiveLastRun {
  final DateTime ranAt;
  final int archivedCount;
  final int leftAloneCount;
  final BulkArchiveResult ready;

  const BulkArchiveLastRun({
    required this.ranAt,
    required this.archivedCount,
    required this.leftAloneCount,
    required this.ready,
  });

  factory BulkArchiveLastRun.fromJson(Map<String, dynamic> json) => BulkArchiveLastRun(
        ranAt: DateTime.parse(json['ranAt'].toString()),
        archivedCount: (json['archivedCount'] as num?)?.toInt() ?? 0,
        leftAloneCount: (json['leftAloneCount'] as num?)?.toInt() ?? 0,
        ready: BulkArchiveResult.fromJson(
            json['ready'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
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
