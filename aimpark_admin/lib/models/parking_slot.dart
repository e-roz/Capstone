class ParkingSlot {
  final String slotId;
  final String slotCode;
  final int gate;
  final String? vehicleType;
  final String status;

  const ParkingSlot({
    required this.slotId,
    required this.slotCode,
    required this.gate,
    required this.vehicleType,
    required this.status,
  });

  bool get isMotorcycle => vehicleType == 'Motorcycle';

  factory ParkingSlot.fromJson(Map<String, dynamic> json) => ParkingSlot(
        slotId: json['slotId']?.toString() ?? '',
        slotCode: json['slotCode']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 1,
        vehicleType: json['vehicleType']?.toString(),
        status: json['status']?.toString() ?? '',
      );
}

/// "The wrong kind of vehicle may be in this bay", raised when a bay's sensor
/// fills. Names the bay only: the sensor can't say who parked there, so a
/// guard goes and looks.
class WrongBayFlag {
  final String flagId;
  final String slotId;
  final String slotCode;
  final int gate;

  /// What the bay is for: 'Car' or 'Motorcycle'.
  final String? bayType;

  /// 'Open' (nobody has looked yet) or 'Confirmed'. False alarms aren't sent.
  final String status;

  final DateTime detectedAt;
  final String? reviewedByName;

  const WrongBayFlag({
    required this.flagId,
    required this.slotId,
    required this.slotCode,
    required this.gate,
    required this.bayType,
    required this.status,
    required this.detectedAt,
    required this.reviewedByName,
  });

  bool get isConfirmed => status == 'Confirmed';

  /// "four-wheel" or "motorcycle", for sentences.
  String get bayKind => bayType == 'Motorcycle' ? 'motorcycle' : 'four-wheel';

  factory WrongBayFlag.fromJson(Map<String, dynamic> json) => WrongBayFlag(
        flagId: json['flagId']?.toString() ?? '',
        slotId: json['slotId']?.toString() ?? '',
        slotCode: json['slotCode']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 1,
        bayType: json['bayType']?.toString(),
        status: json['status']?.toString() ?? 'Open',
        detectedAt: DateTime.parse(json['detectedAt'].toString()),
        reviewedByName: json['reviewedByName']?.toString(),
      );
}

/// A vehicle currently inside — an entry with no exit recorded yet.
class ActiveParkingSession {
  final String logId;

  /// Empty for a visitor, who has no account.
  final String userId;

  /// The account holder, or the visitor's name.
  final String userName;

  final String? plateNumber;
  final String? slotCode;
  final DateTime entryTime;

  /// Whether this car got in on a card lent to a guest. The guard needs it:
  /// a visitor pays cash on the way out and hands the card back, and neither
  /// is true of anybody else in the list.
  final bool isVisitor;

  const ActiveParkingSession({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.plateNumber,
    required this.slotCode,
    required this.entryTime,
    this.isVisitor = false,
  });

  factory ActiveParkingSession.fromJson(Map<String, dynamic> json) =>
      ActiveParkingSession(
        logId: json['logId']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        plateNumber: json['plateNumber']?.toString(),
        slotCode: json['slotCode']?.toString(),
        entryTime: DateTime.parse(json['entryTime'].toString()),
        isVisitor: json['isVisitor'] as bool? ?? false,
      );
}

class ParkingAvailability {
  final List<ParkingSlot> slots;
  final int totalSlots;

  /// Free bays: in-service bays less the cars inside the lot, not the green
  /// bays. A car that entered counts until its exit tap, wherever it parked.
  final int availableSlots;

  /// The same, per bay type. Null from a server older than this count.
  final int? availableCars;
  final int? availableMotorcycles;

  const ParkingAvailability({
    required this.slots,
    required this.totalSlots,
    required this.availableSlots,
    this.availableCars,
    this.availableMotorcycles,
  });

  factory ParkingAvailability.fromJson(Map<String, dynamic> json) =>
      ParkingAvailability(
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) => ParkingSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
        totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 0,
        availableSlots: (json['availableSlots'] as num?)?.toInt() ?? 0,
        availableCars: (json['availableCars'] as num?)?.toInt(),
        availableMotorcycles: (json['availableMotorcycles'] as num?)?.toInt(),
      );
}
