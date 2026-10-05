import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/api_endpoints.dart';
import '../../models/device_health.dart';
import '../../models/gate_reader.dart';
import '../../models/gate_tap_event.dart';
import '../../theme/theme.dart';
import '../live_camera_view.dart';
import '../ui/ui.dart';

final _clock = DateFormat('HH:mm');

/// Everything the live map shows about one gate's hardware and traffic.
///
/// Read from the guard post's server: its Gate Readers link (reader, port,
/// errors), the camera feed, and today's gate log. Opened from the cloud
/// panel none of that answers; there the map builds it instead from the
/// device list the guard post relays through the cloud ([fromRelayed]), and
/// only says "unknown" — never "down" — when nothing has been relayed.
class GateStatus {
  const GateStatus({
    required this.gate,
    required this.known,
    this.reader,
    this.camera,
    this.readerName,
    this.port,
    this.readerError,
    this.lastTapAt,
    this.entered = 0,
    this.exited = 0,
    this.refused = 0,
    this.countsCapped = false,
    this.recent = const [],
    this.relayed = false,
  });

  final int gate;

  /// Whether the guard post answered at all.
  final bool known;

  /// null = not known. false = linked but disconnected, or nothing linked.
  final bool? reader;
  final bool? camera;

  final String? readerName;
  final String? port;
  final String? readerError;
  final DateTime? lastTapAt;

  /// Today's taps at this gate.
  final int entered;
  final int exited;
  final int refused;

  /// The day had more taps than one page of the log; the counts are a floor.
  final bool countsCapped;

  /// Newest first.
  final List<GateTapEvent> recent;

  /// Built from the device list the guard post sends the cloud, not read
  /// from the guard post itself. Devices are known; today's traffic is not.
  final bool relayed;

  GateTapEvent? get last => recent.isEmpty ? null : recent.first;

  bool get anyDown => reader == false || camera == false;

  static const unknown1 = GateStatus(gate: 1, known: false);
  static const unknown2 = GateStatus(gate: 2, known: false);

  /// One round of checks for both gates. Never throws.
  static Future<Map<int, GateStatus>> fetch(Dio dio, {List<int> gates = const [1, 2]}) async {
    Future<dynamic> get(String path, [Map<String, dynamic>? query]) async {
      try {
        return (await dio.get(path, queryParameters: query)).data;
      } on DioException {
        return null;
      }
    }

    final results = await Future.wait([
      get(ApiEndpoints.gateReaders),
      get(ApiEndpoints.liveGateCameras),
      get(ApiEndpoints.liveGateHistory, {'page': 1, 'pageSize': _historyPage}),
    ]);

    final readersJson = results[0];
    final camerasJson = results[1];
    final historyJson = results[2];

    final readers = readersJson is Map<String, dynamic> ? GateReadersState.fromJson(readersJson) : null;

    final cameras = camerasJson is Map
        ? {
            for (final g in camerasJson['gates'] as List? ?? const [])
              ((g as Map)['gate'] as num).toInt(): g['live'] == true,
          }
        : null;

    final startOfToday = DateUtils.dateOnly(DateTime.now());
    final taps = historyJson is Map
        ? [
            for (final t in historyJson['taps'] as List? ?? const [])
              GateTapEvent.fromJson(t as Map<String, dynamic>),
          ]
        : <GateTapEvent>[];
    final today = taps.where((t) => !t.at.toLocal().isBefore(startOfToday)).toList();
    // A full page that is still all today means the day had more than we read.
    final capped = taps.length >= _historyPage && today.length == taps.length;

    return {
      for (final gate in gates)
        gate: () {
          final linked = readers?.readers.where((r) => r.gate == gate).map((r) => r.deviceId).toSet() ?? {};
          final ports = readers?.ports.where((p) => linked.contains(p.deviceId)).toList() ?? const [];
          // A connected port wins; otherwise show whichever is linked, to name its error.
          final port = ports.where((p) => p.connected).firstOrNull ?? ports.firstOrNull;
          final atGate = today.where((t) => t.gate == gate).toList();

          // A wireless gate behind the hub: linked to one of this gate's
          // readers, or standing for the gate in its name (G2 is gate 2).
          final wireless = port != null
              ? null
              : readers?.hubs
                  .expand((h) => h.nodes.map((n) => (hub: h, node: n)))
                  .where((w) => w.node.isGate &&
                      (w.node.boundTo != null ? linked.contains(w.node.boundTo) : w.node.gate == gate))
                  .firstOrNull;
          final wirelessUp = wireless != null && wireless.hub.connected && wireless.node.online;

          final name = wireless != null
              ? (wireless.node.boundTo == null
                  ? 'Gate $gate board (${wireless.node.node})'
                  : readers?.readers.where((r) => r.deviceId == wireless.node.boundTo).firstOrNull?.name)
              : readers?.readers.where((r) => r.deviceId == port?.deviceId).firstOrNull?.name;

          return GateStatus(
            gate: gate,
            known: readers != null || cameras != null,
            reader: readers == null ? null : (wireless != null ? wirelessUp : (port?.connected ?? false)),
            camera: cameras == null ? null : (cameras[gate] ?? false),
            readerName: name,
            port: wireless != null ? '${wireless.node.node} via ${wireless.hub.port}' : port?.port,
            readerError: wireless != null
                ? (wirelessUp
                    ? null
                    : !wireless.hub.connected
                        ? "The hub isn't connected"
                        : 'No signal from ${wireless.node.node}. Check its power.')
                : port == null
                    ? (readers == null ? null : 'No reader linked to Gate $gate')
                    : (port.connected ? null : (port.error ?? 'Not plugged in')),
            lastTapAt: [
              wireless?.node.lastTapAt,
              port?.lastTapAt,
              atGate.firstOrNull?.at,
            ].whereType<DateTime>().fold<DateTime?>(null, (a, b) => a == null || b.isAfter(a) ? b : a),
            entered: atGate.where((t) => t.opened && t.direction == 'IN').length,
            exited: atGate.where((t) => t.opened && t.direction == 'OUT').length,
            refused: atGate.where((t) => !t.opened && !t.isManual).length,
            countsCapped: capped,
            recent: atGate,
          );
        }(),
    };
  }

  static const _historyPage = 100;

  /// One gate's reader and camera, from the device list the guard post sends
  /// the cloud — what the online panel has instead of the guard post's own
  /// endpoints.
  ///
  /// Rows name their gate in [DeviceHealth.boundTo] ("Gate 2",
  /// "Reader 1 (Gate 2)", "COM5 · Reader 1 (Gate 2)"). A gate with no reader
  /// row reads as down, as it does at the guard post: nothing is taking taps.
  factory GateStatus.fromRelayed(int gate, List<DeviceHealth> devices) {
    final atGate = RegExp(r'\bGate ' '$gate' r'\b');
    bool here(DeviceHealth d) => d.boundTo != null && atGate.hasMatch(d.boundTo!);

    final reader = devices
        .where((d) => (d.kind == 'gateNode' || d.kind == 'gateReader') && here(d))
        // An online one wins, so a spare unplugged reader doesn't hide a working one.
        .fold<DeviceHealth?>(null, (best, d) => best == null || (d.online && !best.online) ? d : best);
    final cameras = devices.where((d) => d.kind == 'camera' && here(d)).toList();

    return GateStatus(
      gate: gate,
      known: true,
      relayed: true,
      reader: reader?.online ?? false,
      camera: cameras.isEmpty ? null : cameras.any((c) => c.online),
      readerName: reader?.name,
      readerError: reader == null
          ? 'No reader linked to Gate $gate'
          : reader.online
              ? null
              : reader.lastError ?? 'Not answering',
      lastTapAt: null,
    );
  }
}

/// "just now", "2m ago", "3h ago".
String ago(DateTime? at) {
  if (at == null) return 'never';
  final d = DateTime.now().difference(at.toLocal());
  if (d.inSeconds < 10) return 'just now';
  if (d.inMinutes < 1) return '${d.inSeconds}s ago';
  if (d.inHours < 1) return '${d.inMinutes}m ago';
  if (d.inDays < 1) return '${d.inHours}h ago';
  return '${d.inDays}d ago';
}

/// The plate if the camera or the account has one, else who tapped.
String _subject(GateTapEvent t) => t.cameraPlate ?? t.registeredPlates?.split(',').first.trim() ?? t.who;

/// "ABC 1234 · ENTERED · 08:42".
String lastEventLine(GateTapEvent t) => '${_subject(t)} · ${t.outcomeLabel} · ${_clock.format(t.at.toLocal())}';

/// Green, red, or grey for unknown.
Color deviceColor(BuildContext context, bool? ok) {
  final t = context.tokens;
  return switch (ok) {
    null => t.status.neutral.solid,
    true => t.status.success.solid,
    false => t.status.danger.solid,
  };
}

// ── Detail panel ─────────────────────────────────────────────────────────────

/// Opens the gate's detail panel: devices, camera, today's traffic, the last
/// five taps, and the guard's Open gate override.
Future<void> showGateDetails(
  BuildContext context, {
  required GateStatus status,
  required Dio dio,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => _GateDetailsDialog(status: status, dio: dio),
  );
}

class _GateDetailsDialog extends StatefulWidget {
  const _GateDetailsDialog({required this.status, required this.dio});

  final GateStatus status;
  final Dio dio;

  @override
  State<_GateDetailsDialog> createState() => _GateDetailsDialogState();
}

class _GateDetailsDialogState extends State<_GateDetailsDialog> {
  bool _opening = false;

  GateStatus get s => widget.status;

  Future<void> _openGate() async {
    final port = s.port;
    if (port == null || s.reader != true) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Open Gate ${s.gate} now?'),
        content: const Text(
          'The barrier opens for a few seconds. No card is checked and no entry '
          'is logged. Use Gate check if the car needs a record.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton.icon(
            onPressed: () => Navigator.pop(ctx, true),
            icon: const Icon(Icons.lock_open, size: 18),
            label: const Text('Open'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _opening = true);
    String message;
    try {
      final res = await widget.dio.post(ApiEndpoints.openGateReader(port));
      message = (res.data as Map?)?['message']?.toString() ?? 'Gate opened.';
    } on DioException catch (e) {
      final data = e.response?.data;
      message = data is Map ? data['message']?.toString() ?? 'Could not open the gate.' : 'Could not reach the server.';
    } finally {
      if (mounted) setState(() => _opening = false);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(AppSpacing.x6, AppSpacing.x5, AppSpacing.x4, 0),
      title: Row(
        children: [
          Icon(Icons.door_sliding_outlined, color: t.text.secondary),
          const SizedBox(width: AppSpacing.x2),
          Expanded(child: Text('Gate ${s.gate}')),
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!s.known)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.x3),
                  child: Text(
                    "Device health and the gate log come from the guard post's server. "
                    "Open this panel there to see them.",
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ),
              _DeviceLine(
                icon: Icons.contactless_outlined,
                label: 'Reader',
                ok: s.reader,
                detail: [
                  if (s.readerName != null) s.readerName!,
                  if (s.port != null) s.port!,
                  if (s.readerError != null) s.readerError!,
                  if (s.reader == true) 'last tap ${ago(s.lastTapAt)}',
                ].join(' · '),
              ),
              const SizedBox(height: AppSpacing.x2),
              _DeviceLine(
                icon: Icons.videocam_outlined,
                label: 'Camera',
                ok: s.camera,
                detail: switch (s.camera) {
                  null => '',
                  true => 'sending pictures',
                  false => 'no picture — start the ALPR app for this gate and sign in',
                },
              ),
              const SizedBox(height: AppSpacing.x4),
              LiveCameraView(gate: s.gate),
              const SizedBox(height: AppSpacing.x4),
              Text('TODAY', style: _eyebrow(context)),
              const SizedBox(height: AppSpacing.x2),
              Wrap(
                spacing: AppSpacing.x4,
                runSpacing: AppSpacing.x2,
                children: [
                  _Count(icon: Icons.south_rounded, label: 'in', value: s.entered, capped: s.countsCapped),
                  _Count(icon: Icons.north_rounded, label: 'out', value: s.exited, capped: s.countsCapped),
                  _Count(
                    icon: Icons.block,
                    label: 'refused',
                    value: s.refused,
                    capped: s.countsCapped,
                    intent: s.refused > 0 ? StatusIntent.danger : null,
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.x4),
              Text('LAST 5 TAPS', style: _eyebrow(context)),
              const SizedBox(height: AppSpacing.x1),
              if (s.recent.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
                  child: Text(
                    s.known ? 'No taps at this gate today.' : '—',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                )
              else
                for (final tap in s.recent.take(5)) _TapRow(tap: tap),
            ],
          ),
        ),
      ),
      actions: [
        if (s.reader == true && s.port != null)
          FilledButton.icon(
            onPressed: _opening ? null : _openGate,
            icon: _opening
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.lock_open, size: 18),
            label: Text('Open Gate ${s.gate}'),
          ),
      ],
    );
  }
}

TextStyle? _eyebrow(BuildContext context) => Theme.of(context).textTheme.labelSmall?.copyWith(
  color: context.tokens.text.tertiary,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

class _DeviceLine extends StatelessWidget {
  const _DeviceLine({required this.icon, required this.label, required this.ok, required this.detail});

  final IconData icon;
  final String label;
  final bool? ok;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final word = switch (ok) {
      null => 'Unknown',
      true => 'Online',
      false => 'Offline',
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: t.text.secondary),
        const SizedBox(width: AppSpacing.x2),
        SizedBox(width: 64, child: Text(label, style: text.bodyMedium)),
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6, right: AppSpacing.x2),
          decoration: BoxDecoration(shape: BoxShape.circle, color: deviceColor(context, ok)),
        ),
        Expanded(
          child: Text.rich(
            TextSpan(
              text: word,
              style: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
              children: [
                if (detail.isNotEmpty)
                  TextSpan(
                    text: '  $detail',
                    style: text.bodySmall?.copyWith(color: t.text.secondary, fontWeight: FontWeight.w400),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({
    required this.icon,
    required this.label,
    required this.value,
    required this.capped,
    this.intent,
  });

  final IconData icon;
  final String label;
  final int value;
  final bool capped;
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final color = intent == null ? t.text.primary : t.status.of(intent!).fg;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: AppSizes.iconSm, color: color),
        const SizedBox(width: AppSpacing.x1),
        Text(
          '$value${capped ? '+' : ''}',
          style: AppTypography.tabular(text.titleMedium!.copyWith(color: color)),
        ),
        const SizedBox(width: AppSpacing.x1),
        Text(label, style: text.bodySmall?.copyWith(color: t.text.secondary)),
      ],
    );
  }
}

class _TapRow extends StatelessWidget {
  const _TapRow({required this.tap});

  final GateTapEvent tap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(tap.opened ? StatusIntent.success : StatusIntent.danger);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1 + 2),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Text(
              _clock.format(tap.at.toLocal()),
              style: AppTypography.tabular(text.bodySmall!.copyWith(color: t.text.secondary)),
            ),
          ),
          Expanded(
            child: Text(
              _subject(tap),
              overflow: TextOverflow.ellipsis,
              style: text.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          StatusPill(
            label: tap.outcomeLabel,
            intent: tap.opened ? StatusIntent.success : StatusIntent.danger,
            dense: true,
          ),
          if (!tap.opened && tap.message.isNotEmpty) ...[
            const SizedBox(width: AppSpacing.x1),
            Tooltip(
              message: tap.message,
              child: Icon(Icons.info_outline, size: 16, color: c.fg),
            ),
          ],
        ],
      ),
    );
  }
}
