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

/// A vehicle currently inside — an entry with no exit recorded yet.
class ActiveParkingSession {
  final String logId;
  final String userId;
  final String userName;
  final String? plateNumber;
  final String? slotCode;
  final DateTime entryTime;

  const ActiveParkingSession({
    required this.logId,
    required this.userId,
    required this.userName,
    required this.plateNumber,
    required this.slotCode,
    required this.entryTime,
  });

  factory ActiveParkingSession.fromJson(Map<String, dynamic> json) =>
      ActiveParkingSession(
        logId: json['logId']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        plateNumber: json['plateNumber']?.toString(),
        slotCode: json['slotCode']?.toString(),
        entryTime: DateTime.parse(json['entryTime'].toString()),
      );
}

class ParkingAvailability {
  final List<ParkingSlot> slots;
  final int totalSlots;
  final int availableSlots;

  const ParkingAvailability({
    required this.slots,
    required this.totalSlots,
    required this.availableSlots,
  });

  factory ParkingAvailability.fromJson(Map<String, dynamic> json) =>
      ParkingAvailability(
        slots: (json['slots'] as List<dynamic>? ?? [])
            .map((s) => ParkingSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
        totalSlots: (json['totalSlots'] as num?)?.toInt() ?? 0,
        availableSlots: (json['availableSlots'] as num?)?.toInt() ?? 0,
      );
}
