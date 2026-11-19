/// What parking costs for one vehicle type, as management set it.
///
/// A car keeps the rate it came in with: a change made while it is parked
/// applies from its next entry. The server does that sum, so this is only for
/// showing the price.
class ParkingRate {
  const ParkingRate({
    required this.vehicleType,
    required this.ratePerHour,
    required this.minimumFee,
    required this.updatedAt,
  });

  /// "Car" or "Motorcycle".
  final String vehicleType;
  final double ratePerHour;

  /// The least one visit costs.
  final double minimumFee;

  /// When this rate took effect.
  final DateTime updatedAt;

  bool get isMotorcycle => vehicleType.toLowerCase().contains('motor');

  factory ParkingRate.fromJson(Map<String, dynamic> json) => ParkingRate(
    vehicleType: json['vehicleType'] as String? ?? 'Car',
    ratePerHour: (json['ratePerHour'] as num?)?.toDouble() ?? 0,
    minimumFee: (json['minimumFee'] as num?)?.toDouble() ?? 0,
    updatedAt:
        DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );
}
