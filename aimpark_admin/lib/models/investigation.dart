import 'gate_tap_event.dart';

/// One line in the Overview's search results.
class SearchResult {
  const SearchResult({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.subject,
  });

  /// `person`, `visitor`, `card` (a card nobody holds) or `plate` (a plate the
  /// camera read that nobody registered).
  final String kind;
  final String title;
  final String subtitle;

  /// What to ask the profile endpoint for.
  final InvestigationSubject subject;

  factory SearchResult.fromJson(Map<String, dynamic> json) => SearchResult(
        kind: json['kind'] as String? ?? 'person',
        title: json['title'] as String? ?? '',
        subtitle: json['subtitle'] as String? ?? '',
        subject: InvestigationSubject(
          userId: json['userId'] as String?,
          visitorPassId: json['visitorPassId'] as String?,
          card: json['card'] as String?,
          plate: json['plate'] as String?,
        ),
      );
}

/// Who or what a profile is about. Exactly one field is set: it is the
/// profile endpoint's contract.
class InvestigationSubject {
  const InvestigationSubject({
    this.userId,
    this.visitorPassId,
    this.card,
    this.plate,
  });

  final String? userId;
  final String? visitorPassId;
  final String? card;
  final String? plate;

  /// The most telling thing a gate tap points at: the card when there is one
  /// (the profile is then the holder's), else the plate the camera read.
  /// Null when the tap has neither, e.g. a guard opening the gate by hand.
  static InvestigationSubject? ofTap(GateTapEvent tap) {
    final card = tap.rfidTagId;
    if (card != null && card.isNotEmpty) return InvestigationSubject(card: card);
    final plate = tap.cameraPlate;
    if (plate != null && plate.isNotEmpty) {
      return InvestigationSubject(plate: plate);
    }
    return null;
  }

  Map<String, dynamic> get query => {
        'userId': ?userId,
        'visitorPassId': ?visitorPassId,
        'card': ?card,
        'plate': ?plate,
      };

  @override
  bool operator ==(Object other) =>
      other is InvestigationSubject &&
      other.userId == userId &&
      other.visitorPassId == visitorPassId &&
      other.card == card &&
      other.plate == plate;

  @override
  int get hashCode => Object.hash(userId, visitorPassId, card, plate);
}

class ProfileVehicle {
  const ProfileVehicle({
    required this.plate,
    required this.vehicleType,
    required this.color,
  });

  final String plate;
  final String vehicleType;
  final String color;

  factory ProfileVehicle.fromJson(Map<String, dynamic> json) => ProfileVehicle(
        plate: json['plate'] as String? ?? '',
        vehicleType: json['vehicleType'] as String? ?? '',
        color: json['color'] as String? ?? '',
      );
}

class ProfilePerson {
  const ProfilePerson({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.affiliation,
    required this.studentNumber,
    required this.accountStatus,
    required this.rfidTagId,
    required this.rfidStatus,
    required this.archived,
    required this.vehicles,
  });

  final String id;
  final String fullName;
  final String email;
  final String role;
  final String affiliation;
  final String? studentNumber;
  final String accountStatus;
  final String? rfidTagId;
  final String rfidStatus;
  final bool archived;
  final List<ProfileVehicle> vehicles;

  factory ProfilePerson.fromJson(Map<String, dynamic> json) => ProfilePerson(
        id: json['id'] as String,
        fullName: json['fullName'] as String? ?? '',
        email: json['email'] as String? ?? '',
        role: json['role'] as String? ?? '',
        affiliation: json['affiliation'] as String? ?? '',
        studentNumber: json['studentNumber'] as String?,
        accountStatus: json['accountStatus'] as String? ?? '',
        rfidTagId: json['rfidTagId'] as String?,
        rfidStatus: json['rfidStatus'] as String? ?? '',
        archived: json['archived'] as bool? ?? false,
        vehicles: [
          for (final v in json['vehicles'] as List? ?? const [])
            ProfileVehicle.fromJson(v as Map<String, dynamic>),
        ],
      );
}

class ProfileVisitor {
  const ProfileVisitor({
    required this.id,
    required this.visitorName,
    required this.plateNumber,
    required this.rfidTagId,
    required this.purpose,
    required this.issuedAt,
    required this.expiresAt,
    required this.returnedAt,
  });

  final String id;
  final String visitorName;
  final String plateNumber;
  final String rfidTagId;
  final String? purpose;
  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? returnedAt;

  factory ProfileVisitor.fromJson(Map<String, dynamic> json) => ProfileVisitor(
        id: json['id'] as String,
        visitorName: json['visitorName'] as String? ?? '',
        plateNumber: json['plateNumber'] as String? ?? '',
        rfidTagId: json['rfidTagId'] as String? ?? '',
        purpose: json['purpose'] as String?,
        issuedAt: DateTime.parse(json['issuedAt'] as String),
        expiresAt: DateTime.parse(json['expiresAt'] as String),
        returnedAt: json['returnedAt'] == null
            ? null
            : DateTime.parse(json['returnedAt'] as String),
      );
}

class ProfileSession {
  const ProfileSession({
    required this.id,
    required this.entryTime,
    required this.exitTime,
    required this.gate,
    required this.plate,
    required this.plateMatched,
    this.slotCode,
    this.slotConfirmed = false,
  });

  final String id;
  final DateTime entryTime;
  final DateTime? exitTime;
  final int? gate;
  final String? plate;
  final bool? plateMatched;

  /// The bay on the session. Only the driver's own pick when [slotConfirmed];
  /// otherwise the bay the gate suggested.
  final String? slotCode;
  final bool slotConfirmed;

  factory ProfileSession.fromJson(Map<String, dynamic> json) => ProfileSession(
        id: json['id'] as String,
        entryTime: DateTime.parse(json['entryTime'] as String),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'] as String),
        gate: (json['gate'] as num?)?.toInt(),
        plate: json['plate'] as String?,
        plateMatched: json['plateMatched'] as bool?,
        slotCode: json['slotCode'] as String?,
        slotConfirmed: json['slotConfirmed'] == true,
      );
}

class ProfileViolation {
  const ProfileViolation({
    required this.id,
    required this.ruleTitle,
    required this.status,
    required this.penaltyAmount,
    required this.createdAt,
  });

  final String id;
  final String ruleTitle;
  final String status;
  final double penaltyAmount;
  final DateTime createdAt;

  factory ProfileViolation.fromJson(Map<String, dynamic> json) =>
      ProfileViolation(
        id: json['id'] as String,
        ruleTitle: json['ruleTitle'] as String? ?? '',
        status: json['status'] as String? ?? '',
        penaltyAmount: (json['penaltyAmount'] as num?)?.toDouble() ?? 0,
        createdAt: DateTime.parse(json['createdAt'] as String),
      );
}

/// An incident this person filed. An incident has no plate or vehicle of its
/// own, so "filed by" is the only link there is.
class ProfileIncident {
  const ProfileIncident({
    required this.id,
    required this.category,
    required this.status,
    required this.createdAt,
    required this.preview,
  });

  final String id;
  final String category;
  final String status;
  final DateTime createdAt;
  final String preview;

  factory ProfileIncident.fromJson(Map<String, dynamic> json) =>
      ProfileIncident(
        id: json['id'] as String,
        category: json['category'] as String? ?? '',
        status: json['status'] as String? ?? '',
        createdAt: DateTime.parse(json['createdAt'] as String),
        preview: json['preview'] as String? ?? '',
      );
}

/// How much sits behind each list, since a list shows only the latest few.
class ProfileTotals {
  const ProfileTotals({
    this.taps = 0,
    this.deniedTaps = 0,
    this.seriousDeniedTaps = 0,
    this.sessions = 0,
    this.violations = 0,
    this.incidents = 0,
  });

  final int taps;
  final int deniedTaps;
  final int seriousDeniedTaps;
  final int sessions;
  final int violations;
  final int incidents;

  factory ProfileTotals.fromJson(Map<String, dynamic> json) => ProfileTotals(
        taps: (json['taps'] as num?)?.toInt() ?? 0,
        deniedTaps: (json['deniedTaps'] as num?)?.toInt() ?? 0,
        seriousDeniedTaps: (json['seriousDeniedTaps'] as num?)?.toInt() ?? 0,
        sessions: (json['sessions'] as num?)?.toInt() ?? 0,
        violations: (json['violations'] as num?)?.toInt() ?? 0,
        incidents: (json['incidents'] as num?)?.toInt() ?? 0,
      );
}

/// Everything the system holds about one person, visitor card, unknown card
/// or unregistered plate.
class InvestigationProfile {
  const InvestigationProfile({
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.person,
    required this.visitor,
    required this.card,
    required this.plate,
    required this.totals,
    required this.taps,
    required this.sessions,
    required this.violations,
    required this.incidents,
  });

  /// `person`, `visitor`, `card` or `plate`.
  final String kind;
  final String title;
  final String subtitle;
  final ProfilePerson? person;
  final ProfileVisitor? visitor;
  final String? card;
  final String? plate;
  final ProfileTotals totals;
  final List<GateTapEvent> taps;
  final List<ProfileSession> sessions;
  final List<ProfileViolation> violations;
  final List<ProfileIncident> incidents;

  /// Nobody is behind it: a card nobody holds or a plate nobody registered.
  bool get isUnknown => kind == 'card' || kind == 'plate';

  factory InvestigationProfile.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) read) => [
          for (final e in json[key] as List? ?? const [])
            read(e as Map<String, dynamic>),
        ];

    return InvestigationProfile(
      kind: json['kind'] as String? ?? 'person',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      person: json['person'] == null
          ? null
          : ProfilePerson.fromJson(json['person'] as Map<String, dynamic>),
      visitor: json['visitor'] == null
          ? null
          : ProfileVisitor.fromJson(json['visitor'] as Map<String, dynamic>),
      card: json['card'] as String?,
      plate: json['plate'] as String?,
      totals: ProfileTotals.fromJson(
          (json['totals'] as Map?)?.cast<String, dynamic>() ?? const {}),
      taps: list('taps', GateTapEvent.fromJson),
      sessions: list('sessions', ProfileSession.fromJson),
      violations: list('violations', ProfileViolation.fromJson),
      incidents: list('incidents', ProfileIncident.fromJson),
    );
  }
}
