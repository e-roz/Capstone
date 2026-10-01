import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/alert_sound.dart';
import '../models/device_health.dart';
import '../providers/device_health_provider.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// One row per device the guard post depends on: is it up, when was it last
/// heard from, and — when it isn't right — the one thing to try first.
///
/// Shared by the guard's Overview and the administrator's dashboard so the
/// two can never disagree about what "offline" means. Also raises the
/// offline / back-online alerts, because whichever of the two is open is the
/// screen a person is watching.
class DeviceHealthList extends ConsumerWidget {
  const DeviceHealthList({super.key, this.dark = false});

  /// Drawn on the dashboard's inverse card.
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(deviceHealthProvider, (previous, next) {
      _announce(context, previous?.report, next.report);
    });

    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final health = ref.watch(deviceHealthProvider);
    final report = health.report;
    final muted = dark ? t.text.inverseMuted : t.text.secondary;

    if (!health.atGuardPost) {
      return _Note(
        dark: dark,
        text: 'Device health is read from the guard post\'s server. Open the '
            'panel from the guard post\'s PC to see each device.',
      );
    }
    if (report == null) {
      return health.error == null
          ? const Padding(
              padding: EdgeInsets.all(AppSpacing.x4),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : _Note(dark: dark, text: health.error!);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (health.error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.x2),
            child: Text('${health.error} Showing the last answer.',
                style: text.bodySmall?.copyWith(color: muted)),
          ),
        for (final (i, device) in report.devices.indexed) ...[
          if (i > 0)
            Divider(
              height: 1,
              color: dark
                  ? t.text.inverseMuted.withValues(alpha: 0.16)
                  : t.border.subtle,
            ),
          _DeviceRow(device: device, report: report, dark: dark),
        ],
      ],
    );
  }

  /// Compares two checks and says what changed. A hub going down takes its
  /// boards with it; that is one alert about the hub, not five.
  static void _announce(
    BuildContext context,
    DeviceHealthReport? before,
    DeviceHealthReport? after,
  ) {
    if (before == null || after == null) return;

    final wentDown = <DeviceHealth>[];
    final cameBack = <DeviceHealth>[];
    for (final now in after.devices) {
      final then = before.byId(now.id);
      if (then == null || then.online == now.online) continue;
      (now.online ? cameBack : wentDown).add(now);
    }

    bool behindChanged(DeviceHealth d, List<DeviceHealth> list) =>
        d.dependsOn != null && list.any((o) => o.id == d.dependsOn);
    final down = wentDown.where((d) => !behindChanged(d, wentDown)).toList();
    final back = cameBack.where((d) => !behindChanged(d, cameBack)).toList();
    if (down.isEmpty && back.isEmpty) return;

    String withBoards(DeviceHealth d, List<DeviceHealth> list) {
      final behind = list.where((o) => o.dependsOn == d.id).length;
      return behind == 0
          ? d.name
          : '${d.name} (and the $behind board${behind == 1 ? '' : 's'} behind it)';
    }

    final lines = [
      for (final d in down)
        '${withBoards(d, wentDown)} went offline. ${deviceFixTip(d, after) ?? ''}'.trim(),
      for (final d in back) '${withBoards(d, cameBack)} is back online.',
    ];

    if (down.isNotEmpty) {
      AlertSound.beep();
    } else {
      AlertSound.chime();
    }

    final tone = context.tokens.status.of(
      down.isNotEmpty ? StatusIntent.danger : StatusIntent.success,
    );
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      SnackBar(
        backgroundColor: tone.bg,
        duration: Duration(seconds: down.isNotEmpty ? 10 : 4),
        content: Row(
          children: [
            Icon(
              down.isNotEmpty ? Icons.portable_wifi_off : Icons.wifi_tethering,
              color: tone.fg,
              size: AppSizes.iconMd,
            ),
            const SizedBox(width: AppSpacing.x3),
            Expanded(
              child: Text(lines.join('\n'), style: TextStyle(color: tone.fg)),
            ),
          ],
        ),
      ),
    );
  }
}

/// The one thing to try first, or null when the device is fine.
String? deviceFixTip(DeviceHealth d, DeviceHealthReport report) {
  if (d.condition == DeviceCondition.ok) return null;
  if (d.condition == DeviceCondition.unlinked) {
    return 'Not linked. Pick what it stands for in Gate → Gate Readers.';
  }

  final parent = report.byId(d.dependsOn);
  if (parent != null && !parent.online) {
    return 'Reports through the ${parent.name}. Fix that first.';
  }

  final error = (d.lastError ?? '').toLowerCase();
  final node = d.name.split(' ').last;

  return switch (d.kind) {
    'cloud' =>
      'No internet. The gates still work; records are sent when it is back.',
    'hub' when error.contains('not the hub') =>
      'This board has the wrong sketch. Flash aimpark_espnow_hub onto it.',
    'hub' when error.contains('denied') || error.contains('in use') =>
      'Another program has the port. Close the Arduino Serial Monitor.',
    'hub' when error.contains('not answering') || error.contains('stopped') =>
      'The hub isn\'t answering. Unplug its USB cable and plug it back in.',
    'hub' => 'Check the hub\'s USB cable. It reconnects by itself.',
    'gateNode' when error.contains('revoked') || error.contains('deleted') =>
      'Link $node to an active reader in Gate → Gate Readers.',
    'gateNode' when d.online =>
      'Answers aren\'t reaching $node. Move it closer to the hub or check its power.',
    'gateNode' =>
      'Check $node\'s power. It rejoins within a few seconds of booting.',
    'slotSensor' => d.online
        ? 'Readings aren\'t reaching $node. Check its power.'
        : 'Check $node\'s wiring. Its slot keeps its last status until then.',
    'sensorBoard' =>
      'Check $node\'s power. Its slots keep their last status until it rejoins.',
    'gateReader' when error.contains('hub') =>
      'Link this port as a hub in Gate → Gate Readers.',
    'gateReader' =>
      'Check the USB cable, then Gate → Gate Readers.',
    'camera' => 'Start the ALPR app on this PC and sign in.',
    _ => null,
  };
}

/// "just now", "12s ago", "4m ago", "2h ago", "3d ago", or "never".
String lastSeenLabel(DateTime? at, {DateTime? now}) {
  if (at == null) return 'never';
  final ago = (now ?? DateTime.now()).difference(at.toLocal());
  if (ago.inSeconds < 5) return 'just now';
  if (ago.inMinutes < 1) return '${ago.inSeconds}s ago';
  if (ago.inHours < 1) return '${ago.inMinutes}m ago';
  if (ago.inDays < 1) return '${ago.inHours}h ago';
  return '${ago.inDays}d ago';
}

class _DeviceRow extends StatelessWidget {
  const _DeviceRow({
    required this.device,
    required this.report,
    required this.dark,
  });

  final DeviceHealth device;
  final DeviceHealthReport report;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final d = device;

    final (label, intent) = switch (d.condition) {
      DeviceCondition.ok => ('Online', StatusIntent.success),
      DeviceCondition.degraded => ('Check', StatusIntent.warning),
      DeviceCondition.down when d.kind == 'cloud' => ('Offline', StatusIntent.warning),
      DeviceCondition.down => ('Offline', StatusIntent.danger),
      DeviceCondition.unlinked => ('Not linked', StatusIntent.neutral),
    };
    final tip = deviceFixTip(d, report);
    final primary = dark ? t.text.inverse : t.text.primary;
    final muted = dark ? t.text.inverseMuted : t.text.secondary;
    final tone = t.status.of(intent);

    final subtitle = [
      ?d.boundTo,
      if (d.condition != DeviceCondition.down) ?d.detail,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(_icon(d.kind), size: AppSizes.iconSm, color: muted),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: text.bodyMedium?.copyWith(
                            color: primary, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty)
                      Text(subtitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(color: muted)),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.x2),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Tooltip(
                    message: d.lastError ?? '',
                    child: StatusPill(label: label, intent: intent, dense: true),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    d.kind == 'cloud' && d.online
                        ? 'synced ${lastSeenLabel(d.lastSeenAt)}'
                        : 'seen ${lastSeenLabel(d.lastSeenAt)}',
                    style: AppTypography.tabular(text.labelSmall!)
                        .copyWith(color: muted),
                  ),
                ],
              ),
            ],
          ),
          if (tip != null && d.condition != DeviceCondition.unlinked)
            Padding(
              padding: const EdgeInsets.only(
                  left: AppSizes.iconSm + AppSpacing.x2, top: AppSpacing.x1),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline,
                      size: 14, color: dark ? tone.solid : tone.fg),
                  const SizedBox(width: AppSpacing.x1),
                  Expanded(
                    child: Text(tip,
                        style: text.bodySmall?.copyWith(
                            color: dark ? t.text.inverse : tone.fg)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static IconData _icon(String kind) => switch (kind) {
        'cloud' => Icons.cloud_outlined,
        'hub' => Icons.hub_outlined,
        'gateNode' => Icons.sensor_door_outlined,
        'slotSensor' => Icons.sensors,
        'sensorBoard' => Icons.developer_board_outlined,
        'gateReader' => Icons.usb,
        'camera' => Icons.videocam_outlined,
        _ => Icons.memory,
      };
}

class _Note extends StatelessWidget {
  const _Note({required this.text, required this.dark});

  final String text;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: dark ? t.text.inverseMuted : t.text.secondary),
      ),
    );
  }
}
