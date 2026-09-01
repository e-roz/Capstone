/// A physical card an admin might hand out — revoked from a previous holder
/// and either free to reissue or blocked from ever being reissued. See
/// `AimPark.API.Entities.RfidCard` for why the split exists.
class RfidCard {
  final String rfidTagId;
  final String state; // 'Free' or 'Blocked'
  final String reason;
  final String? note;
  final String lastUserId;
  final String lastUserName;
  final DateTime updatedAt;

  const RfidCard({
    required this.rfidTagId,
    required this.state,
    required this.reason,
    required this.note,
    required this.lastUserId,
    required this.lastUserName,
    required this.updatedAt,
  });

  factory RfidCard.fromJson(Map<String, dynamic> json) => RfidCard(
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        state: json['state']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        note: json['note']?.toString(),
        lastUserId: json['lastUserId']?.toString() ?? '',
        lastUserName: json['lastUserName']?.toString() ?? '',
        updatedAt: DateTime.parse(json['updatedAt'].toString()),
      );
}

/// The reasons a revoke can be recorded with, in the order shown in dropdowns.
/// Must match `AimPark.API.Enums.RfidRevokeReason` — a value the API does not
/// recognise fails the revoke rather than silently landing wrong.
class RfidRevokeReasons {
  RfidRevokeReasons._();

  static const graduated = 'Graduated';
  static const noLongerNeeded = 'NoLongerNeeded';
  static const damaged = 'Damaged';
  static const lost = 'Lost';
  static const stolen = 'Stolen';
  static const other = 'Other';

  static const all = [graduated, noLongerNeeded, damaged, lost, stolen, other];

  /// The label shown to the admin — "NoLongerNeeded" split into words.
  static String label(String reason) => switch (reason) {
        graduated => 'Graduated',
        noLongerNeeded => 'No longer needed',
        damaged => 'Damaged',
        lost => 'Lost',
        stolen => 'Stolen',
        other => 'Other',
        _ => reason,
      };

  /// Whether this reason blocks the card from being reissued — kept in sync
  /// with the same rule in `AdminUserService.RevokeCardAsync` purely so the
  /// dialog can warn the admin before they submit, not as the source of truth.
  static bool blocks(String reason) =>
      reason == lost || reason == stolen || reason == damaged;
}
