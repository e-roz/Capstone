/// A vehicle the gate will open for.
class Vehicle {
  const Vehicle({
    required this.id,
    required this.plateNumber,
    required this.vehicleType,
    required this.color,
    this.registrationValidThrough,
    required this.createdAt,
  });

  final String id;

  /// What the camera at the gate matches on.
  final String plateNumber;

  /// `Car` or `Motorcycle` — the API's own names, which slot allocation uses.
  final String vehicleType;

  final String color;

  /// Null when no receipt has been read for this vehicle yet.
  final DateTime? registrationValidThrough;

  final DateTime createdAt;

  /// True once the registration this vehicle was admitted on has run out.
  ///
  /// Worth surfacing because nothing re-checks a vehicle after it is approved:
  /// an expired registration keeps opening the gate, and the owner is the only
  /// person in a position to notice.
  bool get isRegistrationExpired {
    final expiry = registrationValidThrough;
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id']?.toString() ?? '',
        plateNumber: json['plateNumber']?.toString() ?? '',
        vehicleType: json['vehicleType']?.toString() ?? '',
        color: json['color']?.toString() ?? '',
        registrationValidThrough:
            DateTime.tryParse(json['registrationValidThrough']?.toString() ?? ''),
        createdAt:
            DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
                DateTime.now(),
      );
}
