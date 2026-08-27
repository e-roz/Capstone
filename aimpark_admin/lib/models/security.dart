/// A spare RFID card lent to somebody with no AimPark account.
class VisitorPass {
  final String passId;
  final String rfidTagId;
  final String visitorName;
  final String plateNumber;
  final String vehicleType;
  final String? purpose;
  final String? contactNumber;

  /// Active, Returned or Expired.
  final String status;

  final DateTime issuedAt;
  final DateTime expiresAt;
  final DateTime? returnedAt;
  final String? issuedByName;

  /// True while the visitor's vehicle is still in the lot. A card must not be
  /// taken back before the car has left, or nothing can close the session.
  final bool isInside;

  final String? slotCode;

  const VisitorPass({
    required this.passId,
    required this.rfidTagId,
    required this.visitorName,
    required this.plateNumber,
    required this.vehicleType,
    required this.purpose,
    required this.contactNumber,
    required this.status,
    required this.issuedAt,
    required this.expiresAt,
    required this.returnedAt,
    required this.issuedByName,
    required this.isInside,
    required this.slotCode,
  });

  bool get isActive => status == 'Active';

  factory VisitorPass.fromJson(Map<String, dynamic> json) => VisitorPass(
        passId: json['passId']?.toString() ?? '',
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        visitorName: json['visitorName']?.toString() ?? '',
        plateNumber: json['plateNumber']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString() ?? '',
        purpose: json['purpose']?.toString(),
        contactNumber: json['contactNumber']?.toString(),
        status: json['status']?.toString() ?? '',
        issuedAt: DateTime.parse(json['issuedAt'].toString()),
        expiresAt: DateTime.parse(json['expiresAt'].toString()),
        returnedAt: json['returnedAt'] == null
            ? null
            : DateTime.parse(json['returnedAt'].toString()),
        issuedByName: json['issuedByName']?.toString(),
        isInside: json['isInside'] as bool? ?? false,
        slotCode: json['slotCode']?.toString(),
      );
}

class VisitorPassListPage {
  final List<VisitorPass> passes;
  final int totalCount;
  final int page;
  final int pageSize;

  const VisitorPassListPage({
    required this.passes,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory VisitorPassListPage.fromJson(Map<String, dynamic> json) =>
      VisitorPassListPage(
        passes: (json['passes'] as List<dynamic>? ?? [])
            .map((p) => VisitorPass.fromJson(p as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}

/// A vehicle a card is allowed to arrive on.
class TagVehicle {
  final String plateNumber;
  final String vehicleType;
  final String? color;
  final bool registrationExpired;

  const TagVehicle({
    required this.plateNumber,
    required this.vehicleType,
    required this.color,
    required this.registrationExpired,
  });

  factory TagVehicle.fromJson(Map<String, dynamic> json) => TagVehicle(
        plateNumber: json['plateNumber']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString() ?? '',
        color: json['color']?.toString(),
        registrationExpired: json['registrationExpired'] as bool? ?? false,
      );
}

/// What a guard sees when they look up the card in front of them.
///
/// This is the guard's half of dual-factor verification: the reader proves the
/// card is genuine, and this says which vehicle ought to be attached to it, so
/// a person can check the two agree.
class TagLookup {
  /// "User", "Visitor" or "Unknown".
  final String holder;

  final String? name;
  final String? affiliation;
  final List<TagVehicle> vehicles;

  /// Whether the barrier would open for this card right now.
  final bool accessAllowed;

  /// Why not, when it would not.
  final String? deniedReason;

  final bool isInside;
  final String? slotCode;
  final DateTime? entryTime;

  /// Set only for a visitor card.
  final DateTime? passExpiresAt;

  const TagLookup({
    required this.holder,
    required this.name,
    required this.affiliation,
    required this.vehicles,
    required this.accessAllowed,
    required this.deniedReason,
    required this.isInside,
    required this.slotCode,
    required this.entryTime,
    required this.passExpiresAt,
  });

  bool get isKnown => holder != 'Unknown';
  bool get isVisitor => holder == 'Visitor';

  factory TagLookup.fromJson(Map<String, dynamic> json) => TagLookup(
        holder: json['holder']?.toString() ?? 'Unknown',
        name: json['name']?.toString(),
        affiliation: json['affiliation']?.toString(),
        vehicles: (json['vehicles'] as List<dynamic>? ?? [])
            .map((v) => TagVehicle.fromJson(v as Map<String, dynamic>))
            .toList(),
        accessAllowed: json['accessAllowed'] as bool? ?? false,
        deniedReason: json['deniedReason']?.toString(),
        isInside: json['isInside'] as bool? ?? false,
        slotCode: json['slotCode']?.toString(),
        entryTime: json['entryTime'] == null
            ? null
            : DateTime.parse(json['entryTime'].toString()),
        passExpiresAt: json['passExpiresAt'] == null
            ? null
            : DateTime.parse(json['passExpiresAt'].toString()),
      );
}
