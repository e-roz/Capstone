/// One vehicle entry/exit as recorded at a gate.
///
/// Projected server-side from `ParkingLog`, so this carries no state of its own
/// — it is a read model for the System Logs module and nothing writes it back.
class RfidAccessLogEntry {
  final String id;
  final String userId;
  final String userName;
  final String? rfidTagId;
  final String? slotCode;
  final int? gate;
  final DateTime entryTime;
  final DateTime? exitTime;

  /// "Device" for a real reader scan, "Manual" for a staff correction keyed in
  /// from the panel.
  final String source;

  /// Reader name, or the staff account that keyed it in.
  final String? recordedBy;

  final DateTime createdAt;

  const RfidAccessLogEntry({
    required this.id,
    required this.userId,
    required this.userName,
    required this.rfidTagId,
    required this.slotCode,
    required this.gate,
    required this.entryTime,
    required this.exitTime,
    required this.source,
    required this.recordedBy,
    required this.createdAt,
  });

  /// Null while the vehicle is still inside.
  Duration? get duration => exitTime?.difference(entryTime);

  bool get isInside => exitTime == null;

  factory RfidAccessLogEntry.fromJson(Map<String, dynamic> json) =>
      RfidAccessLogEntry(
        id: json['id']?.toString() ?? '',
        userId: json['userId']?.toString() ?? '',
        userName: json['userName']?.toString() ?? '',
        rfidTagId: json['rfidTagId']?.toString(),
        slotCode: json['slotCode']?.toString(),
        gate: (json['gate'] as num?)?.toInt(),
        entryTime: DateTime.parse(json['entryTime'].toString()),
        exitTime: json['exitTime'] == null
            ? null
            : DateTime.parse(json['exitTime'].toString()),
        source: json['source']?.toString() ?? '',
        recordedBy: json['recordedBy']?.toString(),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

class RfidAccessLogPage {
  final List<RfidAccessLogEntry> logs;
  final int totalCount;
  final int page;
  final int pageSize;

  const RfidAccessLogPage({
    required this.logs,
    required this.totalCount,
    required this.page,
    required this.pageSize,
  });

  factory RfidAccessLogPage.fromJson(Map<String, dynamic> json) =>
      RfidAccessLogPage(
        logs: (json['logs'] as List<dynamic>? ?? [])
            .map((l) => RfidAccessLogEntry.fromJson(l as Map<String, dynamic>))
            .toList(),
        totalCount: (json['totalCount'] as num?)?.toInt() ?? 0,
        page: (json['page'] as num?)?.toInt() ?? 1,
        pageSize: (json['pageSize'] as num?)?.toInt() ?? 20,
      );
}
