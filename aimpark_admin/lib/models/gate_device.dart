/// Hardware at a gate — an RFID reader or an ALPR camera — or the guard
/// post's own server, identified to the API by a long-lived key instead of a
/// staff login.
enum GateDeviceType {
  rfidReader,
  alprCamera,

  /// The guard post's server (SITE_SERVER.md). Its key only reaches the
  /// sync endpoints, never a barrier. Issue it with gate 0.
  siteServer;

  /// The API has no `JsonStringEnumConverter` registered, so this crosses the
  /// wire as the enum's raw index (0/1/2), not its name. Declaration order
  /// matches the API's GateDeviceType, so the index is the wire value.
  static GateDeviceType fromJson(dynamic value) {
    final index = (value as num?)?.toInt() ?? 0;
    return index >= 0 && index < GateDeviceType.values.length
        ? GateDeviceType.values[index]
        : GateDeviceType.rfidReader;
  }

  int toJson() => index;

  String get label => switch (this) {
        GateDeviceType.rfidReader => 'RFID Reader',
        GateDeviceType.alprCamera => 'ALPR Camera',
        GateDeviceType.siteServer => 'Site Server',
      };
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
