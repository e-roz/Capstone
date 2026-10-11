class ParkingSlot {
  const ParkingSlot({
    required this.slotId,
    required this.slotCode,
    required this.status,
    this.gate = 1,
    this.vehicleType,
  });

  final String slotId;
  final String slotCode;
  final int gate;
  final String? vehicleType;
  final String status;

  factory ParkingSlot.fromJson(Map<String, dynamic> json) {
    return ParkingSlot(
      slotId: json['slotId'] as String,
      slotCode: json['slotCode'] as String,
      gate: (json['gate'] as num?)?.toInt() ?? 1,
      vehicleType: json['vehicleType'] as String?,
      status: json['status'] as String,
    );
  }
}

/// Outcome codes returned by `POST /api/parking/recommend`. These mirror the
/// server's `AllocationResult` constants — the gate hardware branches on the
/// same values, so they are part of the contract rather than display text.
abstract final class AllocationResult {
  static const assigned = 'ASSIGNED';
  static const lotFull = 'LOT_FULL';
  static const noVehicleRegistered = 'NO_VEHICLE_REGISTERED';
}

class SlotOption {
  const SlotOption({required this.slotId, required this.slotCode, required this.gate});

  final String slotId;
  final String slotCode;
  final int gate;

  factory SlotOption.fromJson(Map<String, dynamic> json) => SlotOption(
        slotId: json['slotId'] as String,
        slotCode: json['slotCode'] as String,
        gate: (json['gate'] as num?)?.toInt() ?? 1,
      );
}

class SlotRecommendation {
  const SlotRecommendation({
    required this.result,
    this.slotId,
    this.slotCode,
    this.gate,
    this.reason,
    this.alternatives = const [],
  });

  final String result;
  final String? slotId;
  final String? slotCode;
  final int? gate;
  final String? reason;
  final List<SlotOption> alternatives;

  bool get isAssigned => result == AllocationResult.assigned;

  factory SlotRecommendation.fromJson(Map<String, dynamic> json) {
    return SlotRecommendation(
      result: json['result'] as String? ?? AllocationResult.lotFull,
      slotId: json['slotId'] as String?,
      slotCode: json['slotCode'] as String?,
      gate: (json['gate'] as num?)?.toInt(),
      reason: json['reason'] as String?,
      alternatives: (json['alternatives'] as List<dynamic>? ?? [])
          .map((e) => SlotOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ParkingAvailability {
  ParkingAvailability({
    required this.slots,
    required this.totalSlots,
    required this.availableSlots,
    this.availableCars,
    this.availableMotorcycles,
    this.lastHeardAt,
    this.feedPaused = false,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.now();

  final List<ParkingSlot> slots;
  final int totalSlots;
  final int availableSlots;

  /// The server's per-type free counts. Null from a server older than them.
  final int? availableCars;
  final int? availableMotorcycles;

  /// When the lot's guard post last reported, by the server's clock. This is the
  /// age of the count. [fetchedAt] is only when the phone last asked, and says
  /// nothing about whether the sensors have been heard from. Null from an older
  /// server, or one that has not heard from the guard post since it started.
  final DateTime? lastHeardAt;

  /// The server says the guard post has gone quiet: every bay is reported as No
  /// signal and nothing is counted free.
  final bool feedPaused;

  final DateTime fetchedAt;

  /// How old the count is: by the server's word when it gave one, otherwise by
  /// the phone's.
  DateTime get asOf => lastHeardAt ?? fetchedAt;

  factory ParkingAvailability.fromJson(Map<String, dynamic> json) {
    return ParkingAvailability(
      slots: (json['slots'] as List<dynamic>)
          .map((e) => ParkingSlot.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalSlots: json['totalSlots'] as int,
      availableSlots: json['availableSlots'] as int,
      availableCars: (json['availableCars'] as num?)?.toInt(),
      availableMotorcycles: (json['availableMotorcycles'] as num?)?.toInt(),
      lastHeardAt: json['lastHeardAt'] == null
          ? null
          : DateTime.parse(json['lastHeardAt'] as String),
      feedPaused: json['feedPaused'] as bool? ?? false,
      fetchedAt: DateTime.now(),
    );
  }
}
