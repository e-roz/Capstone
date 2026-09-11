/// Hardware at a gate — an RFID reader or an ALPR camera — identified to the
/// API by a long-lived key instead of a staff login.
enum GateDeviceType {
  rfidReader,
  alprCamera;

  /// The API has no `JsonStringEnumConverter` registered, so this crosses the
  /// wire as the enum's raw index (0/1), not its name.
  static GateDeviceType fromJson(dynamic value) =>
      (value as num?)?.toInt() == 1
          ? GateDeviceType.alprCamera
          : GateDeviceType.rfidReader;

  int toJson() => this == GateDeviceType.alprCamera ? 1 : 0;

  String get label =>
      this == GateDeviceType.alprCamera ? 'ALPR Camera' : 'RFID Reader';
}

class GateDevice {
  final String deviceId;
  final String name;
  final int gate;
  final GateDeviceType deviceType;

  /// Leading characters of the key, kept in clear so devices sharing a gate
  /// can be told apart without ever showing the real key again.
  final String apiKeyPrefix;

  final bool isRevoked;
  final DateTime? lastSeenAt;
  final DateTime createdAt;

  const GateDevice({
    required this.deviceId,
    required this.name,
    required this.gate,
    required this.deviceType,
    required this.apiKeyPrefix,
    required this.isRevoked,
    required this.lastSeenAt,
    required this.createdAt,
  });

  /// Gate 0 is the enrollment desk reader, not a barrier — see
  /// ApiKeyDefaults.EnrollmentGate on the API.
  String get gateLabel => gate == 0 ? 'Enrollment desk' : 'Gate $gate';

  factory GateDevice.fromJson(Map<String, dynamic> json) => GateDevice(
        deviceId: json['deviceId']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 0,
        deviceType: GateDeviceType.fromJson(json['deviceType']),
        apiKeyPrefix: json['apiKeyPrefix']?.toString() ?? '',
        isRevoked: json['isRevoked'] as bool? ?? false,
        lastSeenAt: json['lastSeenAt'] == null
            ? null
            : DateTime.parse(json['lastSeenAt'].toString()),
        createdAt: DateTime.parse(json['createdAt'].toString()),
      );
}

/// What creating a device returns — the only moment the real key ever exists
/// outside the device itself. Never re-fetched, never stored in state past
/// the dialog that shows it.
class CreatedGateDevice {
  final String name;
  final int gate;
  final GateDeviceType deviceType;
  final String apiKey;
  final String warning;

  const CreatedGateDevice({
    required this.name,
    required this.gate,
    required this.deviceType,
    required this.apiKey,
    required this.warning,
  });

  factory CreatedGateDevice.fromJson(Map<String, dynamic> json) =>
      CreatedGateDevice(
        name: json['name']?.toString() ?? '',
        gate: (json['gate'] as num?)?.toInt() ?? 0,
        deviceType: GateDeviceType.fromJson(json['deviceType']),
        apiKey: json['apiKey']?.toString() ?? '',
        warning: json['warning']?.toString() ?? '',
      );
}
