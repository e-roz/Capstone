/// One vehicle's stay in the lot, as recorded at a gate.
///
/// Projected server-side from `ParkingLog`, so this carries no state of its own
/// — it is a read model for the Parking Logs page and nothing writes it back.
class ParkingLogEntry {
  final String id;
  final String userName;
  final bool isVisitor;

  /// What a visitor is here for, as the guard wrote it. Null for members.
  final String? visitorPurpose;

  final String? rfidTagId;

  /// "Car" or "Motorcycle"; null when it cannot be told.
  final String? vehicleType;

  /// What the camera read, else the registered plate; null when neither is known.
  final String? plateNumber;

  final int? gate;
  final DateTime entryTime;
  final DateTime? exitTime;

  /// The bay the driver confirmed in the app; null until they confirm. The bay
  /// suggested at entry is not carried, since it is only a guess.
  final String? confirmedSlotCode;

  /// When the driver confirmed.
  final DateTime? slotConfirmedAt;

  /// Where the session stands on confirming, worked out by the server.
  final BayConfirmState confirmState;

  /// An admin moved the driver's confirmed bay.
  final bool bayCorrected;

  const ParkingLogEntry({
    required this.id,
    required this.userName,
    required this.isVisitor,
    required this.visitorPurpose,
    required this.rfidTagId,
    required this.vehicleType,
    required this.plateNumber,
    required this.gate,
    required this.entryTime,
    required this.exitTime,
    this.confirmedSlotCode,
    this.slotConfirmedAt,
    this.confirmState = BayConfirmState.notCounted,
    this.bayCorrected = false,
  });

  /// Null while the vehicle is still inside.
  Duration? get duration => exitTime?.difference(entryTime);

  bool get isInside => exitTime == null;

  bool get isSlotConfirmed => confirmedSlotCode != null;

  factory ParkingLogEntry.fromJson(Map<String, dynamic> json) => ParkingLogEntry(
        id: json['id']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        isVisitor: json['isVisitor'] == true,
        visitorPurpose: json['visitorPurpose']?.toString(),
        rfidTagId: json['rfidTagId']?.toString(),
        vehicleType: json['vehicleType']?.toString(),
        plateNumber: json['plateNumber']?.toString(),
        gate: (json['gate'] as num?)?.toInt(),
        entryTime: DateTime.parse(json['entryTime'].toString()),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'].toString()),
        confirmedSlotCode: json['confirmedSlotCode']?.toString(),
        slotConfirmedAt: json['slotConfirmedAt'] == null
            ? null
            : DateTime.parse(json['slotConfirmedAt'].toString()),
        confirmState: BayConfirmState.parse(json['confirmState']?.toString()),
        bayCorrected: json['bayCorrected'] == true,
      );
}

/// Whether a driver said which bay they used. Mirrors the server's
/// `BayConfirmState`.
enum BayConfirmState {
  /// Still inside, not confirmed yet. Not a problem yet.
  notYet,
  confirmed,

  /// Confirmed after leaving, the same day.
  confirmedLate,

  /// Left without confirming. Counts toward a warning and a strike.
  unconfirmed,

  /// A visitor or a very short stay, never asked to confirm.
  notCounted;

  static BayConfirmState parse(String? value) => switch (value) {
    'NotYet' => notYet,
    'Confirmed' => confirmed,
    'ConfirmedLate' => confirmedLate,
    'Unconfirmed' => unconfirmed,
    _ => notCounted,
  };

  bool get isConfirmed => this == confirmed || this == confirmedLate;
}

/// A session's confirmed bay as the driver gave it, and every admin
/// correction since.
class BayConfirmHistory {
  final String? driverSlotCode;
  final DateTime? driverConfirmedAt;
  final String? currentSlotCode;
  final BayConfirmState state;
  final List<BayCorrection> corrections;

  const BayConfirmHistory({
    required this.driverSlotCode,
    required this.driverConfirmedAt,
    required this.currentSlotCode,
    required this.state,
    required this.corrections,
  });

  factory BayConfirmHistory.fromJson(Map<String, dynamic> json) =>
      BayConfirmHistory(
        driverSlotCode: json['driverSlotCode']?.toString(),
        driverConfirmedAt: json['driverConfirmedAt'] == null
            ? null
            : DateTime.parse(json['driverConfirmedAt'].toString()),
        currentSlotCode: json['currentSlotCode']?.toString(),
        state: BayConfirmState.parse(json['state']?.toString()),
        corrections: (json['corrections'] as List<dynamic>? ?? [])
            .map((c) => BayCorrection.fromJson(c as Map<String, dynamic>))
            .toList(),
      );
}

class BayCorrection {
  final String fromSlotCode;
  final String toSlotCode;
  final String reason;
  final String correctedByName;
  final DateTime correctedAt;

  const BayCorrection({
    required this.fromSlotCode,
    required this.toSlotCode,
    required this.reason,
    required this.correctedByName,
    required this.correctedAt,
  });

  factory BayCorrection.fromJson(Map<String, dynamic> json) => BayCorrection(
        fromSlotCode: json['fromSlotCode']?.toString() ?? '',
        toSlotCode: json['toSlotCode']?.toString() ?? '',
        reason: json['reason']?.toString() ?? '',
        correctedByName: json['correctedByName']?.toString() ?? '',
        correctedAt: DateTime.parse(json['correctedAt'].toString()),
      );
}

class ParkingLogPage {
  final List<ParkingLogEntry> logs;

  /// False at the guard post, which never hears of a confirm: there the
  /// Confirmed column would call everyone unconfirmed, so it is hidden.
  final bool confirmationsTracked;

  final int totalCount;
  final int page;
  final int pageSize;

  const ParkingLogPage({
    required this.logs,
    this.confirmationsTracked = true,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory ParkingLogPage.fromJson(Map<String, dynamic> json) => ParkingLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => ParkingLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        confirmationsTracked: json['confirmationsTracked'] != false,
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
