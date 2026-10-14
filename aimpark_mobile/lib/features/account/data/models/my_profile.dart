class MyProfile {
  const MyProfile({
    required this.userId,
    required this.fullName,
    required this.email,
    required this.role,
    required this.accountStatus,
    required this.createdAt,
    this.phoneNumber,
    this.licenseValidThrough,
  });

  final String userId;
  final String fullName;
  final String email;
  final String? phoneNumber;
  final String role;
  final String accountStatus;
  final DateTime createdAt;

  /// When the driver's licence on file runs out. Null if it was never read.
  final DateTime? licenseValidThrough;

  factory MyProfile.fromJson(Map<String, dynamic> json) {
    return MyProfile(
      userId: json['userId'] as String,
      fullName: json['fullName'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String?,
      role: json['role'] as String,
      accountStatus: json['accountStatus'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      licenseValidThrough:
          DateTime.tryParse(json['licenseValidThrough']?.toString() ?? ''),
    );
  }
}

class AccessStatus {
  const AccessStatus({
    required this.rfidStatus,
    required this.accountStatus,
    this.rfidTagId,
    this.isSuspendedNow = false,
    this.suspensionStartsAt,
    this.suspensionEndsAt,
    this.entryBlockedReason,
    this.outstandingBalance,
  });

  final String? rfidTagId;
  final String rfidStatus;
  final String accountStatus;

  /// Whether the gate would refuse the card right now.
  ///
  /// Not the same as `rfidStatus == 'Suspended'`. A suspension that comes with
  /// a violation is scheduled a few days out so the user can appeal first, and
  /// the status reads Suspended for that whole window while the card still
  /// works.
  final bool isSuspendedNow;

  /// When a scheduled suspension begins, or null when none is waiting. Non-null
  /// means the appeal window is still open and this is its deadline.
  final DateTime? suspensionStartsAt;

  /// When a temporary suspension lifts. Null if permanent.
  final DateTime? suspensionEndsAt;

  /// True while the card still works but a suspension is already on the books.
  bool get hasPendingSuspension => suspensionStartsAt != null;

  /// Why the gate would refuse *entry* for a reason other than the card's own
  /// status — today only `UNPAID_BALANCE`. Null when nothing blocks, and null
  /// from a server that does not send it yet, so this is always safe to read.
  final String? entryBlockedReason;

  /// What the account owes, when the server says. Null when nothing is owed or
  /// the server predates the field.
  final double? outstandingBalance;

  /// Entry is refused until a bill is paid. Exit never is.
  bool get isEntryBlockedByBalance => entryBlockedReason == 'UNPAID_BALANCE';

  factory AccessStatus.fromJson(Map<String, dynamic> json) {
    DateTime? date(String key) {
      final raw = json[key];
      return raw == null ? null : DateTime.tryParse(raw.toString())?.toLocal();
    }

    return AccessStatus(
      rfidTagId: json['rfidTagId'] as String?,
      rfidStatus: json['rfidStatus'] as String,
      accountStatus: json['accountStatus'] as String,
      // Defaulted rather than required: an app talking to an API that predates
      // appeal windows should still render the card.
      isSuspendedNow: json['isSuspendedNow'] as bool? ??
          (json['rfidStatus'] as String).toLowerCase() == 'suspended',
      suspensionStartsAt: date('suspensionStartsAt'),
      suspensionEndsAt: date('suspensionEndsAt'),
      entryBlockedReason: json['entryBlockedReason'] as String?,
      outstandingBalance: (json['outstandingBalance'] as num?)?.toDouble(),
    );
  }
}
