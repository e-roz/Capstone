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
  final String runId;
  final DateTime ranAt;
  final String reason;
  final int archivedCount;
  final int leftAloneCount;
  final BulkArchiveResult ready;
  final BulkArchiveAuto auto;

  /// How many of the people this run archived are still archived.
  final int restorableCount;

  /// False once undone, and on runs made before undo existed.
  final bool canUndo;
  final DateTime? undoneAt;

  /// The run's "archive when clear" list. Empty when it was never turned on.
  final List<BulkArchivePending> pending;

  const BulkArchiveLastRun({
    required this.runId,
    required this.ranAt,
    required this.reason,
    required this.archivedCount,
    required this.leftAloneCount,
    required this.ready,
    required this.auto,
    required this.pending,
    this.restorableCount = 0,
    this.canUndo = false,
    this.undoneAt,
  });

  factory BulkArchiveLastRun.fromJson(Map<String, dynamic> json) => BulkArchiveLastRun(
        runId: json['runId']?.toString() ?? '',
        ranAt: DateTime.parse(json['ranAt'].toString()),
        reason: json['reason']?.toString() ?? '',
        archivedCount: (json['archivedCount'] as num?)?.toInt() ?? 0,
        leftAloneCount: (json['leftAloneCount'] as num?)?.toInt() ?? 0,
        ready: BulkArchiveResult.fromJson(
            json['ready'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
        auto: BulkArchiveAuto.fromJson(
            json['auto'] as Map<String, dynamic>? ?? const <String, dynamic>{}),
        pending: [
          for (final p in json['pending'] as List<dynamic>? ?? const [])
            BulkArchivePending.fromJson(p as Map<String, dynamic>),
        ],
        restorableCount: (json['restorableCount'] as num?)?.toInt() ?? 0,
        canUndo: json['canUndo'] == true,
        undoneAt: _date(json['undoneAt']),
      );

  int count(String state) => pending.where((p) => p.state == state).length;
}

/// A run's "archive when clear" settings.
class BulkArchiveAuto {
  final bool enabled;
  final int graceDays;
  final DateTime? until;
  final DateTime? stoppedAt;

  const BulkArchiveAuto({
    required this.enabled,
    required this.graceDays,
    this.until,
    this.stoppedAt,
  });

  factory BulkArchiveAuto.fromJson(Map<String, dynamic> json) => BulkArchiveAuto(
        enabled: json['enabled'] == true,
        graceDays: (json['graceDays'] as num?)?.toInt() ?? 7,
        until: _date(json['autoArchiveUntil']),
        stoppedAt: _date(json['stoppedAt']),
      );
}

/// One person on a run's "archive when clear" list.
class BulkArchivePending {
  /// Waiting, Warned, Archived, Kept, Cancelled or Expired.
  static const waiting = 'Waiting';
  static const warned = 'Warned';
  static const archived = 'Archived';
  static const kept = 'Kept';
  static const cancelled = 'Cancelled';
  static const expired = 'Expired';
  static const restored = 'Restored';

  final String id;
  final String userId;
  final String fullName;
  final String email;
  final String state;
  final String? note;
  final DateTime? warnedAt;
  final DateTime? archiveAt;
  final DateTime? resolvedAt;

  const BulkArchivePending({
    required this.id,
    required this.userId,
    required this.fullName,
    required this.email,
    required this.state,
    this.note,
    this.warnedAt,
    this.archiveAt,
    this.resolvedAt,
  });

  bool get isOpen => state == waiting || state == warned;

  factory BulkArchivePending.fromJson(Map<String, dynamic> json) => BulkArchivePending(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        fullName: json['fullName']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        state: json['state']?.toString() ?? waiting,
        note: json['note']?.toString(),
        warnedAt: _date(json['warnedAt']),
        archiveAt: _date(json['archiveAt']),
        resolvedAt: _date(json['resolvedAt']),
      );
}

DateTime? _date(Object? v) => v == null ? null : DateTime.tryParse(v.toString());

/// The answer to a bulk restore or an undo: who came back, and who was
/// asked for but not restored (not archived any more, not found).
class BulkRestoreResult {
  final List<String> restoredNames;
  final List<BulkArchiveSkip> skipped;

  const BulkRestoreResult({required this.restoredNames, required this.skipped});

  int get restored => restoredNames.length;

  factory BulkRestoreResult.fromJson(Map<String, dynamic> json) => BulkRestoreResult(
        restoredNames: [
          for (final r in json['restored'] as List<dynamic>? ?? const [])
            (r as Map<String, dynamic>)['fullName']?.toString() ?? '',
        ],
        skipped: [
          for (final s in json['skipped'] as List<dynamic>? ?? const [])
            BulkArchiveSkip.fromJson(s as Map<String, dynamic>),
        ],
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
