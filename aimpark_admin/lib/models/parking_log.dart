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
  });

  /// Null while the vehicle is still inside.
  Duration? get duration => exitTime?.difference(entryTime);

  bool get isInside => exitTime == null;

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
      );
}

class ParkingLogPage {
  final List<ParkingLogEntry> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const ParkingLogPage({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory ParkingLogPage.fromJson(Map<String, dynamic> json) => ParkingLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => ParkingLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
