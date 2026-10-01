/// One device the guard post depends on, as the site server sees it right
/// now: the hub and the boards behind it, the USB readers, each gate's
/// camera, and the link to the cloud.
class DeviceHealth {
  /// Stable across checks — "hub:COM5", "node:COM5:G1", "camera:…", "cloud" —
  /// so a change between two checks can be told apart from a new row.
  final String id;
  final String name;

  /// "cloud", "hub", "gateNode", "slotSensor", "gateReader" or "camera".
  final String kind;

  /// What it stands for: a gate's reader, a slot, a COM port.
  final String? boundTo;

  /// False for a board behind the hub that nobody has linked yet.
  final bool bound;
  final bool online;
  final DateTime? lastSeenAt;
  final String? lastError;
  final DateTime? lastErrorAt;

  /// The row this one can't work without — a gate node's hub.
  final String? dependsOn;
  final String? detail;

  /// Slot sensors: what it last saw.
  final bool? occupied;
  final int? distanceCm;

  const DeviceHealth({
    required this.id,
    required this.name,
    required this.kind,
    required this.boundTo,
    required this.bound,
    required this.online,
    required this.lastSeenAt,
    required this.lastError,
    required this.lastErrorAt,
    required this.dependsOn,
    required this.detail,
    required this.occupied,
    required this.distanceCm,
  });

  DeviceCondition get condition => switch (this) {
        DeviceHealth(online: false, bound: true) => DeviceCondition.down,
        DeviceHealth(online: false) => DeviceCondition.unlinked,
        DeviceHealth(bound: false) => DeviceCondition.unlinked,
        DeviceHealth(lastError: _?) => DeviceCondition.degraded,
        _ => DeviceCondition.ok,
      };

  factory DeviceHealth.fromJson(Map<String, dynamic> json) => DeviceHealth(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? '',
        kind: json['kind']?.toString() ?? '',
        boundTo: json['boundTo']?.toString(),
        bound: json['bound'] as bool? ?? true,
        online: json['online'] as bool? ?? false,
        lastSeenAt: _date(json['lastSeenAt']),
        lastError: json['lastError']?.toString(),
        lastErrorAt: _date(json['lastErrorAt']),
        dependsOn: json['dependsOn']?.toString(),
        detail: json['detail']?.toString(),
        occupied: json['occupied'] as bool?,
        distanceCm: (json['distanceCm'] as num?)?.toInt(),
      );
}

enum DeviceCondition {
  ok,

  /// Up, but something went wrong lately — an answer that didn't arrive.
  degraded,

  down,

  /// A board nobody has said the purpose of. Not a fault.
  unlinked,
}

class DeviceHealthReport {
  final DateTime checkedAt;
  final List<DeviceHealth> devices;

  const DeviceHealthReport({required this.checkedAt, required this.devices});

  DeviceHealth? byId(String? id) =>
      id == null ? null : devices.where((d) => d.id == id).firstOrNull;

  factory DeviceHealthReport.fromJson(Map<String, dynamic> json) =>
      DeviceHealthReport(
        checkedAt: _date(json['checkedAt']) ?? DateTime.now().toUtc(),
        devices: [
          for (final d in json['devices'] as List<dynamic>? ?? const [])
            DeviceHealth.fromJson(d as Map<String, dynamic>),
        ],
      );
}

DateTime? _date(dynamic value) =>
    value == null ? null : DateTime.parse(value.toString());
