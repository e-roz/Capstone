/// One physical card the panel knows about: on a user's account right now
/// (`Assigned`), revoked and free to reissue (`Free`), or revoked and never to
/// be reissued (`Blocked`). See `AimPark.API.Entities.RfidCard` for why the
/// Free/Blocked split exists.
class RfidCard {
  final String rfidTagId;
  final String state; // 'Assigned', 'Free' or 'Blocked'

  /// Why the card was revoked. Empty for an assigned card.
  final String reason;
  final String? note;

  /// Who the card was last taken from. Empty for an assigned card.
  final String lastUserId;
  final String lastUserName;

  /// When the card last changed hands. Null for an assigned card the audit
  /// log has no assign row for.
  final DateTime? updatedAt;

  // Filled only when [isAssigned].
  final String? holderUserId;
  final String? holderName;
  final String? holderStudentNumber;
  final String? holderAffiliation;
  final String? holderRole;
  final String? holderRfidStatus;
  final DateTime? holderSuspendedUntil;
  final bool holderArchived;

  const RfidCard({
    required this.rfidTagId,
    required this.state,
    required this.reason,
    required this.note,
    required this.lastUserId,
    required this.lastUserName,
    required this.updatedAt,
    this.holderUserId,
    this.holderName,
    this.holderStudentNumber,
    this.holderAffiliation,
    this.holderRole,
    this.holderRfidStatus,
    this.holderSuspendedUntil,
    this.holderArchived = false,
  });

  bool get isAssigned => state == RfidCardStates.assigned;
  bool get isFree => state == RfidCardStates.free;
  bool get isBlocked => state == RfidCardStates.blocked;

  factory RfidCard.fromJson(Map<String, dynamic> json) => RfidCard(
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        note: json['note']?.toString(),
        lastUserId: json['lastUserId']?.toString() ?? '',
        lastUserName: json['lastUserName']?.toString() ?? '',
        updatedAt: _date(json['updatedAt']),
        holderUserId: json['holderUserId']?.toString(),
        holderName: json['holderName']?.toString(),
        holderStudentNumber: json['holderStudentNumber']?.toString(),
        holderAffiliation: json['holderAffiliation']?.toString(),
        holderRole: json['holderRole']?.toString(),
        holderRfidStatus: json['holderRfidStatus']?.toString(),
        holderSuspendedUntil: _date(json['holderSuspendedUntil']),
        holderArchived: (json['holderArchived'] as bool?) ?? false,
      );
}

class RfidCardStates {
  RfidCardStates._();

  static const assigned = 'Assigned';
  static const free = 'Free';
  static const blocked = 'Blocked';
}

/// One assign, revoke or reinstate on a card, rebuilt by the API from the
/// admin audit log.
class RfidCardHistoryEntry {
  final String action; // 'AssignRfid', 'RevokeRfid' or 'Reinstate'
  final String? reason;
  final String? note;
  final String userId;
  final String userName;
  final String actorName;
  final DateTime createdAt;

  const RfidCardHistoryEntry({
    required this.action,
    required this.reason,
    required this.note,
    required this.userId,
    required this.userName,
    required this.actorName,
    required this.createdAt,
  });

  factory RfidCardHistoryEntry.fromJson(Map<String, dynamic> json) =>
      RfidCardHistoryEntry(
        action: json['action']?.toString() ?? '',
        reason: json['reason']?.toString(),
        note: json['note']?.toString(),
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        actorName: json['actorName']?.toString() ?? '',
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

DateTime? _date(Object? raw) =>
    raw == null ? null : DateTime.tryParse(raw.toString());

/// The reasons a revoke can be recorded with. Must match
/// `AimPark.API.Enums.RfidRevokeReason` — a value the API does not recognise
/// fails the revoke rather than silently landing wrong.
class RfidRevokeReasons {
  RfidRevokeReasons._();

  static const noLongerNeeded = 'NoLongerNeeded';
  static const damaged = 'Damaged';
  static const lost = 'Lost';
  static const stolen = 'Stolen';
  static const other = 'Other';

  /// No longer offered in the dialog — it was too easy to pick by accident,
  /// and "No longer needed" covers it. Kept so old records still read right.
  static const graduated = 'Graduated';

  /// Set by the API on a third Accountable violation. Never offered in the
  /// dialog — an admin does not pick it by hand.
  static const violationLimit = 'ViolationLimit';

  /// The choices in the revoke dialog, in order.
  static const selectable = [noLongerNeeded, lost, stolen, damaged, other];

  /// The label shown to the admin — "NoLongerNeeded" split into words.
  static String label(String reason) => switch (reason) {
        graduated => 'Graduated',
        noLongerNeeded => 'No longer needed',
        damaged => 'Damaged',
        lost => 'Lost',
        stolen => 'Stolen',
        other => 'Other',
        violationLimit => '3 violations',
        _ => reason,
      };

  /// Whether this reason blocks the card from being reissued — kept in sync
  /// with the same rule in `AdminUserService.RevokeCardAsync` purely so the
  /// dialog can warn the admin before they submit, not as the source of truth.
  static bool blocks(String reason) =>
      reason == lost || reason == stolen || reason == damaged;
}
