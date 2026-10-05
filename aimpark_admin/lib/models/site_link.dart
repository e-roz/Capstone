import 'device_health.dart';

/// The guard post as the cloud sees it.
///
/// The online panel reads the cloud, and the cloud only knows what the guard
/// post sends it. This says how fresh that is: whether the guard post's
/// standing connection is open, when it last sent gate records, and its latest
/// device list.
class SiteLink {
  const SiteLink({
    required this.serverNow,
    required this.connected,
    required this.connectedSince,
    required this.disconnectedAt,
    required this.lastPushAt,
    required this.healthAt,
    required this.devices,
  });

  /// After this long without a health report the map warns that it may be
  /// showing old bays. The guard post reports every 15 s, so 60 s rides out a
  /// few missed sends without crying wolf.
  static const staleAfter = Duration(seconds: 60);

  /// The cloud's clock when it answered. Ages are measured against this, not
  /// the browser's clock, which can be minutes off.
  final DateTime serverNow;

  final bool connected;
  final DateTime? connectedSince;
  final DateTime? disconnectedAt;

  /// Last time gate records — entries, exits, bay changes — arrived.
  final DateTime? lastPushAt;

  /// Last time the guard post sent its device list. Null from a guard post
  /// still running a version that does not send one.
  final DateTime? healthAt;

  final List<DeviceHealth> devices;

  /// The newest thing heard from the guard post.
  DateTime? get lastContact => switch ((lastPushAt, healthAt)) {
        (final a?, final b?) => a.isAfter(b) ? a : b,
        (final a, final b) => a ?? b,
      };

  /// How long ago [lastContact] was, by the cloud's clock.
  Duration? get age => lastContact == null ? null : serverNow.difference(lastContact!);

  /// The guard post is sending device reports, so silence means trouble.
  bool get reportsHealth => healthAt != null;

  /// The bays on the map may no longer match the lot.
  ///
  /// A guard post that never sent a device report (not updated yet) can only
  /// be judged by its connection; one that does is also judged by how long it
  /// has been quiet.
  bool get stale =>
      !connected ||
      (reportsHealth && serverNow.difference(healthAt!) > staleAfter);

  /// When the map stopped being trustworthy, for "offline since 10:42".
  DateTime? get staleSince => !connected ? (disconnectedAt ?? lastContact) : healthAt;

  factory SiteLink.fromJson(Map<String, dynamic> json) => SiteLink(
        serverNow: _date(json['now']) ?? DateTime.now().toUtc(),
        connected: json['connected'] as bool? ?? false,
        connectedSince: _date(json['connectedSince']),
        disconnectedAt: _date(json['disconnectedAt']),
        lastPushAt: _date(json['lastPushAt']),
        healthAt: _date(json['healthAt']),
        devices: [
          for (final d in json['devices'] as List? ?? const [])
            DeviceHealth.fromJson(d as Map<String, dynamic>),
        ],
      );
}

DateTime? _date(dynamic value) => value == null ? null : DateTime.parse(value.toString());
