/// The last card tapped on the enrollment desk reader.
///
/// Read-only and short-lived: the API holds one scan at a time and forgets it
/// after a couple of minutes, so this exists only to carry a UID from the
/// reader on the desk to the Assign dialog on screen.
class RfidScan {
  /// New on every tap. The dialog watches this rather than [rfidTagId], so
  /// tapping the same card twice still reads as a fresh scan.
  final String scanId;

  final String rfidTagId;
  final DateTime scannedAt;

  /// Which reader saw it.
  final String deviceName;

  /// Already on someone's account — assigning it would move the card.
  final bool isAssigned;

  final String? assignedToUserId;
  final String? assignedToName;

  const RfidScan({
    required this.scanId,
    required this.rfidTagId,
    required this.scannedAt,
    required this.deviceName,
    required this.isAssigned,
    required this.assignedToUserId,
    required this.assignedToName,
  });

  factory RfidScan.fromJson(Map<String, dynamic> json) => RfidScan(
        scanId: json['scanId']?.toString() ?? '',
        rfidTagId: json['rfidTagId']?.toString() ?? '',
        scannedAt: DateTime.parse(json['scannedAt'].toString()),
        deviceName: json['deviceName']?.toString() ?? 'Reader',
        isAssigned: json['isAssigned'] == true,
        assignedToUserId: json['assignedToUserId']?.toString(),
        assignedToName: json['assignedToName']?.toString(),
      );
}
