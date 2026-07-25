class ParkingSlot {
  const ParkingSlot({
    required this.slotId,
    required this.slotCode,
    required this.status,
    this.vehicleType,
  });

  final String slotId;
  final String slotCode;
  final String? vehicleType;
  final String status;

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      slotId: json['slotId'] as String,
      slotCode: json['slotCode'] as String,
      vehicleType: json['vehicleType'] as String?,
      status: json['status'] as String,
    );
  }
}

class ParkingAvailability {
  const ParkingAvailability({
    required this.slots,
    required this.totalSlots,
    required this.availableSlots,
  });

  final List<ParkingSlot> slots;
  final int totalSlots;
  final int availableSlots;

  factory ParkingAvailability.fromJson(Map<String, dynamic> json) {
    return ParkingAvailability(
      slots: (json['slots'] as List<dynamic>)
          .map((e) => ParkingSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSlots: json['totalSlots'] as int,
      availableSlots: json['availableSlots'] as int,
    );
  }
}
