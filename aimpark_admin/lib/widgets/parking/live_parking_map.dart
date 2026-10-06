import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../core/utils/ph_time.dart';
import '../../models/device_health.dart';
import '../../models/parking_slot.dart';
import '../../models/site_link.dart';
import '../../providers/device_health_provider.dart';
import '../../providers/parking_provider.dart';
import '../../providers/site_link_provider.dart';
import '../../theme/theme.dart';
import '../ui/ui.dart';
import 'gate_status.dart';

final _clock = DateFormat('HH:mm');

/// The lot as it is built: two columns of nine bays facing each other across
/// a drive lane, Gate 1's barrier at the top, Gate 2's at the bottom, and
/// walls in the four corners.
///
///          ▨▨  [ GATE 1 ]  ▨▨
///     L1                        R1
///     ..        drive lane      ..
///     L9                        R9
///          ▨▨  [ GATE 2 ]  ▨▨
///
/// Gate 1's bays fill the left column and Gate 2's the right, by slot code.
/// Four-wheel bays are the top of the left column and the bottom of the right
/// one, as they are painted on the model. A gate with more than nine bays
/// shows the extra ones under the map instead of hiding them.
///
/// Refreshes itself every few seconds while it is on screen, so an occupied
/// bay changes colour without anyone pressing Refresh.
///
/// The bays come from the guard post, which sends every change to the cloud.
/// At the guard post the panel reads that server directly and the map is
/// live. Online it reads the cloud's copy, so the header says how recently
/// the guard post was heard from and warns when it has gone quiet, instead of
/// claiming "live" over bays that may have stopped updating.
class LiveParkingMapCard extends ConsumerStatefulWidget {
  const LiveParkingMapCard({
    super.key,
    this.compact = false,
    this.onBayTap,
  });

  /// Smaller bays and no plate on them; for the overview screens.
  final bool compact;

  /// Called when a bay is clicked, e.g. to change its status. Null = read-only.
  final void Function(ParkingSlot slot)? onBayTap;

  @override
  ConsumerState<LiveParkingMapCard> createState() => _LiveParkingMapCardState();
}

class _LiveParkingMapCardState extends ConsumerState<LiveParkingMapCard> {
  // A car leaving should free its bay on screen within a second or two.
  static const _refreshEvery = Duration(milliseconds: 1500);
  static const _healthEvery = Duration(seconds: 5);

  Timer? _timer;
  Timer? _healthTimer;

  bool _healthInFlight = false;
  Map<int, GateStatus> _health = const {1: GateStatus.unknown1, 2: GateStatus.unknown2};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
    _checkHealth();
    _healthTimer = Timer.periodic(_healthEvery, (_) => _checkHealth());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _healthTimer?.cancel();
    super.dispose();
  }

  /// Each gate's reader, camera and today's log, from the guard post's
  /// server. From the cloud panel nothing answers and every device reads
  /// "unknown", not "down".
  Future<void> _checkHealth() async {
    if (_healthInFlight) return;
    _healthInFlight = true;
    try {
      final health = await GateStatus.fetch(ref.read(dioProvider));
      if (mounted) setState(() => _health = health);
    } finally {
      _healthInFlight = false;
    }
  }

  void _showGate(int gate) {
    final link = ref.read(siteLinkProvider).valueOrNull;
    final local = _health[gate];
    final status = (local?.known ?? false) || link == null || !link.reportsHealth
        ? local ?? GateStatus(gate: gate, known: false)
        : GateStatus.fromRelayed(gate, link.devices);
    showGateDetails(context, status: status, dio: ref.read(dioProvider));
  }

  void _refresh() {
    // A refresh still in flight is left to finish rather than stacked.
    if (ref.read(parkingSlotsProvider).isLoading) return;
    ref.invalidate(parkingSlotsProvider);
    ref.invalidate(activeParkingSessionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final slots = ref.watch(parkingSlotsProvider);
    final link = ref.watch(siteLinkProvider).valueOrNull;

    // At the guard post its own server answers and the map is first-hand.
    // Online, gate devices come from the list the guard post relays through
    // the cloud.
    final atGuardPost = _health.values.any((h) => h.known);
    final relayed = !atGuardPost && link != null && link.reportsHealth;
    final health = relayed
        ? {for (final g in _health.keys) g: GateStatus.fromRelayed(g, link.devices)}
        : _health;
    // A bay reads free or taken only while a sensor vouches for it.
    final coverage = _SensorCoverage.from(ref.watch(deviceHealthProvider), link);
    final stale = !atGuardPost && link != null && link.stale;
    final sessions = {
      for (final s in ref.watch(activeParkingSessionsProvider).valueOrNull ??
          const <ActiveParkingSession>[])
        if (s.slotCode != null) s.slotCode!: s,
    };

    // No header of its own: the clock and the status badge sit in the page
    // header ([ParkingStatus]), next to the page's actions.
    return AppCard(
      child: AsyncView(
        value: slots,
        onRetry: () => ref.invalidate(parkingSlotsProvider),
        loading: SkeletonBlock(height: widget.compact ? 420 : 560),
        isEmpty: (a) => a.slots.isEmpty,
        empty: const AppEmptyState(
          icon: Icons.local_parking_outlined,
          title: 'No bays configured',
          message: 'Add a slot to start tracking the lot.',
        ),
        data: (availability) => _Coverage(
          coverage: coverage,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stale) ...[
                _StaleBanner(since: link.staleSince),
                const SizedBox(height: AppSpacing.x3),
              ] else if (coverage.count(availability.slots) case (0, > 0)) ...[
                // Said once here, so the bays need not each repeat it.
                const _NoSignalBanner(),
                const SizedBox(height: AppSpacing.x3),
              ],
              // Dimmed, not hidden: the last known bays are still the best
              // guess, but should not look as sure as live ones.
              AnimatedOpacity(
                duration: AppMotion.normal,
                opacity: stale ? 0.55 : 1,
                child: _MapWithSummary(
                  slots: availability.slots,
                  availability: availability,
                  sessions: sessions,
                  compact: widget.compact,
                  onBayTap: widget.onBayTap,
                  health: health,
                  onGateTap: _showGate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Page header status ───────────────────────────────────────────────────────

/// The Philippine clock and how far to trust the bays, for the Parking page's
/// header: "Live", "Sensors offline", "Guard post offline since 10:42"…
class ParkingStatus extends ConsumerStatefulWidget {
  const ParkingStatus({super.key});

  @override
  ConsumerState<ParkingStatus> createState() => _ParkingStatusState();
}

class _ParkingStatusState extends ConsumerState<ParkingStatus> {
  Timer? _ticker;
  DateTime? _updatedAt;

  @override
  void initState() {
    super.initState();
    // Keeps "Live · 2s ago" honest between refreshes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(parkingSlotsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) _updatedAt = DateTime.now();
    });

    final slots = ref.watch(parkingSlotsProvider);
    final link = ref.watch(siteLinkProvider).valueOrNull;
    final deviceHealth = ref.watch(deviceHealthProvider);
    final coverage = _SensorCoverage.from(deviceHealth, link);

    return Wrap(
      spacing: AppSpacing.x3,
      runSpacing: AppSpacing.x1,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        const _PhClock(),
        _SyncBadge(
          atGuardPost: deviceHealth.report != null,
          link: link,
          updatedAt: _updatedAt,
          failing: slots.hasError,
          sensors: coverage.count(slots.valueOrNull?.slots),
        ),
      ],
    );
  }
}

// ── Overview summary ─────────────────────────────────────────────────────────

/// The lot in one card, for the Overview screens: how many bays are free, by
/// vehicle type, whether each gate's reader and camera are up, and how fresh
/// that is — with a link to the full map on the Parking page.
///
/// The whole map used to sit on the Overview, pushing everything else below
/// the fold to answer what is mostly one question: is there room?
class ParkingSummaryCard extends ConsumerWidget {
  const ParkingSummaryCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final slots = ref.watch(parkingSlotsProvider);
    final link = ref.watch(siteLinkProvider).valueOrNull;
    // At the guard post its own server lists the devices; online, the cloud
    // relays the same list.
    final deviceHealth = ref.watch(deviceHealthProvider);
    final local = deviceHealth.report;
    final atGuardPost = local != null;
    final devices = local?.devices ?? (link != null && link.reportsHealth ? link.devices : null);
    final coverage = _SensorCoverage.from(deviceHealth, link);
    final stale = !atGuardPost && link != null && link.stale;

    return AppSectionCard(
      title: 'Parking',
      subtitle: 'Free bays right now, and the gates.',
      icon: Icons.local_parking_outlined,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      actions: [
        _SyncBadge(
          atGuardPost: atGuardPost,
          link: link,
          updatedAt: null,
          failing: slots.hasError,
          sensors: coverage.count(slots.valueOrNull?.slots),
        ),
        TextButton(
          onPressed: () => context.go('/parking'),
          child: const Text('Open parking map'),
        ),
      ],
      child: AsyncView(
        value: slots,
        onRetry: () => ref.invalidate(parkingSlotsProvider),
        loading: const SkeletonBlock(height: 96),
        data: (availability) {
          final usable = availability.slots.where((s) => s.status != 'OutOfService').toList();
          final free = coverage.free(usable, availability.availableSlots);
          final noSignal = usable.where(coverage.silent).length;
          final inBays = usable.where((s) => s.status == 'Occupied' && coverage.confirms(s)).length;
          final notInBay = (usable.length - free - noSignal - inBays).clamp(0, usable.length);
          final freeNotes = [
            if (notInBay == 1) '1 car inside not yet in a bay',
            if (notInBay > 1) '$notInBay cars inside not yet in a bay',
            if (noSignal > 0) '$noSignal with no sensor signal',
          ];

          final (cars, carTotal, carsSilent) =
              coverage.freeOf(usable.where((s) => s.vehicleType == 'Car'), availability.availableCars);
          final (bikes, bikeTotal, bikesSilent) = coverage.freeOf(
              usable.where((s) => s.vehicleType != 'Car'), availability.availableMotorcycles);
          String freeNote(int silent) => silent > 0 ? 'free · $silent no signal' : 'free';

          Widget stat(String label, String value, {String? note, Color? color}) => SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: _eyebrow(context)),
                    const SizedBox(height: AppSpacing.x1),
                    Text(
                      value,
                      style: AppTypography.tabular(text.headlineSmall!.copyWith(color: color)),
                    ),
                    if (note != null)
                      Text(note, style: text.bodySmall?.copyWith(color: t.text.secondary)),
                  ],
                ),
              );

          Widget gate(int g) {
            final status = devices == null ? null : GateStatus.fromRelayed(g, devices);
            return SizedBox(
              width: 150,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GATE $g', style: _eyebrow(context)),
                  const SizedBox(height: AppSpacing.x2),
                  Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x1,
                    children: [
                      _DeviceChip(label: 'Reader', ok: status?.reader),
                      _DeviceChip(label: 'Camera', ok: status?.camera),
                    ],
                  ),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (stale) ...[
                _StaleBanner(since: link.staleSince),
                const SizedBox(height: AppSpacing.x3),
              ],
              AnimatedOpacity(
                duration: AppMotion.normal,
                opacity: stale ? 0.55 : 1,
                child: Wrap(
                  spacing: AppSpacing.x6,
                  runSpacing: AppSpacing.x4,
                  children: [
                    stat(
                      'FREE NOW',
                      '$free of ${usable.length}',
                      // Nothing to vouch for a bay is not a full lot.
                      color: free == 0 && usable.isNotEmpty && noSignal < usable.length
                          ? t.status.danger.fg
                          : null,
                      note: freeNotes.isEmpty ? null : freeNotes.join('\n'),
                    ),
                    stat('FOUR-WHEEL', '$cars / $carTotal', note: freeNote(carsSilent)),
                    stat('MOTORCYCLE', '$bikes / $bikeTotal', note: freeNote(bikesSilent)),
                    gate(1),
                    gate(2),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ── Header badge ─────────────────────────────────────────────────────────────

/// How far to trust the bays: live at the guard post; online, how long ago the
/// guard post was heard from, or since when it has been silent.
class _SyncBadge extends StatelessWidget {
  const _SyncBadge({
    required this.atGuardPost,
    required this.link,
    required this.updatedAt,
    required this.failing,
    required this.sensors,
  });

  final bool atGuardPost;
  final SiteLink? link;

  /// When this panel last read the bays — only meaningful at the guard post.
  final DateTime? updatedAt;
  final bool failing;

  /// Usable bays a live sensor vouches for, of all of them. Null when no
  /// device list reached this panel, and the badge can't say.
  final (int live, int total)? sensors;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    final sensors = this.sensors;
    // The server answering is not the lot reporting: "Live" over bays no
    // sensor can see would pass a dead hub off as an empty lot.
    final sensorsDown = sensors != null && sensors.$1 < sensors.$2;
    final sensorsLabel = sensors == null || sensors.$1 == 0
        ? 'Sensors offline'
        : '${sensors.$1} of ${sensors.$2} sensors live';

    final (intent, label, pulse) = switch (link) {
      _ when failing => (StatusIntent.warning, 'Reconnecting', false),
      _ when atGuardPost && sensorsDown => (StatusIntent.warning, sensorsLabel, false),
      _ when atGuardPost => (
          StatusIntent.success,
          updatedAt == null ? 'Live' : 'Live · ${_ago(DateTime.now().difference(updatedAt!))}',
          true,
        ),
      null => (StatusIntent.neutral, 'Waiting for guard post', false),
      _ when link.stale => (
          StatusIntent.warning,
          link.staleSince == null
              ? 'Guard post offline'
              : 'Guard post offline since ${_clock.format(manila(link.staleSince!))}',
          false,
        ),
      _ when sensorsDown => (StatusIntent.warning, sensorsLabel, false),
      _ when link.age == null => (StatusIntent.success, 'Guard post connected', true),
      _ => (StatusIntent.success, 'Synced from guard post · ${_ago(link.age!)}', true),
    };
    final icon = label == sensorsLabel
        ? Icons.sensors_off_rounded
        : intent == StatusIntent.warning
            ? Icons.cloud_off_rounded
            : Icons.schedule_rounded;

    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(intent);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x1),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.fullAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (pulse)
            _PulseDot(color: c.solid)
          else
            Icon(
              icon,
              size: 12,
              color: c.solid,
            ),
          const SizedBox(width: AppSpacing.x2),
          Text(label, style: AppTypography.tabular(text.labelSmall!.copyWith(color: c.fg))),
        ],
      ),
    );
  }

  static String _ago(Duration d) => d.inSeconds < 2
      ? 'just now'
      : d.inMinutes < 1
          ? '${d.inSeconds}s ago'
          : '${d.inMinutes}m ago';
}

/// Says in words what the amber badge means for the bays below it.
class _StaleBanner extends StatelessWidget {
  const _StaleBanner({required this.since});

  final DateTime? since;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.warning;
    final when = since == null
        ? 'from before the guard post went quiet'
        : 'from ${_clock.format(manila(since!))}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off_rounded, size: AppSizes.iconSm, color: c.fg),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              'Showing the last known status $when. Bays may have changed since.',
              style: text.bodyMedium?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// No bay has a live sensor: the hub is unplugged, or every board is off.
/// Said once above the map instead of on each of the eighteen bays.
class _NoSignalBanner extends StatelessWidget {
  const _NoSignalBanner();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.neutral;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3, vertical: AppSpacing.x2),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Icon(Icons.sensors_off_rounded, size: AppSizes.iconSm, color: c.fg),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Text(
              'No sensor signal from any bay. Check the hub and sensor boards.',
              style: text.bodyMedium?.copyWith(color: c.fg),
            ),
          ),
        ],
      ),
    );
  }
}

/// The date and time in the Philippines, ticking each second. On a narrow
/// screen only the time, so the header keeps room for the badge.
class _PhClock extends StatefulWidget {
  const _PhClock();

  @override
  State<_PhClock> createState() => _PhClockState();
}

class _PhClockState extends State<_PhClock> {
  static final _full = DateFormat('EEE, MMM d, y · h:mm:ss a');
  static final _short = DateFormat('h:mm:ss a');

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final now = manilaNow();
    final wide = MediaQuery.sizeOf(context).width >= 900;

    return Tooltip(
      message: 'Philippine time (UTC+8)',
      child: Text(
        (wide ? _full : _short).format(now),
        style: AppTypography.tabular(text.labelMedium!.copyWith(color: t.text.secondary)),
      ),
    );
  }
}

class _PulseDot extends StatefulWidget {
  const _PulseDot({required this.color});

  final Color color;

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 4 + 6 * _c.value,
              height: 4 + 6 * _c.value,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.35 * (1 - _c.value)),
              ),
            ),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Layout: map beside its numbers ───────────────────────────────────────────

/// Bays per column on the model.
const _rows = 9;

class _MapWithSummary extends StatelessWidget {
  const _MapWithSummary({
    required this.slots,
    required this.availability,
    required this.sessions,
    required this.compact,
    required this.onBayTap,
    required this.health,
    required this.onGateTap,
  });

  final List<ParkingSlot> slots;
  final ParkingAvailability availability;
  final Map<String, ActiveParkingSession> sessions;
  final bool compact;
  final void Function(ParkingSlot slot)? onBayTap;
  final Map<int, GateStatus> health;
  final void Function(int gate) onGateTap;

  @override
  Widget build(BuildContext context) {
    final left = _column(gate: 1, mirrored: false);
    final right = _column(gate: 2, mirrored: true);

    // Bays that don't fit the drawing: a third gate, or a tenth bay at one.
    final placed = {...left, ...right}.map((s) => s.slotId).toSet();
    final unplaced = slots.where((s) => !placed.contains(s.slotId)).toList()
      ..sort((a, b) => a.slotCode.compareTo(b.slotCode));

    final map = _LotMap(
      left: left,
      right: right,
      sessions: sessions,
      compact: compact,
      onBayTap: onBayTap,
      health: health,
      onGateTap: onGateTap,
    );
    final summary = _Summary(slots: slots, availability: availability);
    final lotWidth = _LotMap.widthFor(compact: compact);

    return LayoutBuilder(
      builder: (context, box) {
        // The lot keeps the shape of the real one; the numbers sit right
        // beside it rather than across a stretch of empty page.
        final sideBySide = box.maxWidth >= lotWidth + AppSpacing.x8 + 340;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sideBySide)
              // The gates' details go under the numbers, beside the lot,
              // rather than under it with the page's right side left empty.
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(width: lotWidth, child: map),
                  const SizedBox(width: AppSpacing.x8),
                  Expanded(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 880),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          summary,
                          const SizedBox(height: AppSpacing.x8),
                          Text('GATE HEALTH', style: _eyebrow(context)),
                          const SizedBox(height: AppSpacing.x3),
                          _GateTiles(health: health, onTap: onGateTap),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            else ...[
              // On a phone the whole lot shrinks to fit rather than scroll.
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(width: lotWidth, child: map),
                ),
              ),
              const SizedBox(height: AppSpacing.x5),
              summary,
              const SizedBox(height: AppSpacing.x5),
              Text('GATE HEALTH', style: _eyebrow(context)),
              const SizedBox(height: AppSpacing.x2),
              _GateTiles(health: health, onTap: onGateTap),
            ],
            if (unplaced.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.x5),
              _Unplaced(slots: unplaced, sessions: sessions, onBayTap: onBayTap),
            ],
          ],
        );
      },
    );
  }

  /// One column of the drawing, top to bottom. Four-wheel bays sit at the
  /// top of the left column (C1…C3, M1…M6). The right column is its mirror,
  /// counting down to the bottom (M6…M1, C3…C1). When a gate has more than
  /// nine bays, the overflow comes from the non-car bays, so the four-wheel
  /// bays always keep their painted spots at the end of the column.
  List<ParkingSlot> _column({required int gate, required bool mirrored}) {
    int byCode(ParkingSlot a, ParkingSlot b) => _naturalCompare(a.slotCode, b.slotCode);
    final atGate = slots.where((s) => s.gate == gate).toList();
    final cars = (atGate.where((s) => s.vehicleType == 'Car').toList()..sort(byCode)).take(_rows).toList();
    final others = (atGate.where((s) => s.vehicleType != 'Car').toList()..sort(byCode))
        .take(_rows - cars.length)
        .toList();
    final column = [...cars, ...others];
    return mirrored ? column.reversed.toList() : column;
  }
}

/// "M10" after "M9", not after "M1".
int _naturalCompare(String a, String b) {
  final re = RegExp(r'(\d+)|(\D+)');
  final pa = re.allMatches(a).map((m) => m.group(0)!).toList();
  final pb = re.allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < pa.length && i < pb.length; i++) {
    final na = int.tryParse(pa[i]);
    final nb = int.tryParse(pb[i]);
    final c = (na != null && nb != null) ? na.compareTo(nb) : pa[i].compareTo(pb[i]);
    if (c != 0) return c;
  }
  return pa.length.compareTo(pb.length);
}

// ── The drawing ──────────────────────────────────────────────────────────────

class _LotMap extends StatelessWidget {
  const _LotMap({
    required this.left,
    required this.right,
    required this.sessions,
    required this.compact,
    required this.onBayTap,
    required this.health,
    required this.onGateTap,
  });

  final List<ParkingSlot> left;
  final List<ParkingSlot> right;
  final Map<String, ActiveParkingSession> sessions;
  final bool compact;
  final void Function(ParkingSlot slot)? onBayTap;
  final Map<int, GateStatus> health;
  final void Function(int gate) onGateTap;

  // A stall seen from above is about 2.5 m wide and 5 m deep, and the aisle
  // between the two rows about as wide as a stall is deep. The bays keep
  // that shape instead of stretching across the screen.
  static double _bayLength(bool compact) => compact ? 112 : 164;
  static double _bayWidth(bool compact) => compact ? 46 : 64;
  static double _laneWidth(bool compact) => compact ? 104 : 150;
  static const _padding = AppSpacing.x3;

  /// The lot's full width, border included, for laying out beside it.
  static double widthFor({required bool compact}) =>
      _bayLength(compact) * 2 + _laneWidth(compact) + _padding * 2 + 2;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bayLength = _bayLength(compact);
    final bayHeight = _bayWidth(compact);
    final gap = compact ? AppSpacing.x1 + 1 : AppSpacing.x1 + 2;

    Widget column(List<ParkingSlot> bays, {required bool alignRight}) => Column(
      children: [
        for (var i = 0; i < _rows; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SizedBox(
            width: bayLength,
            height: bayHeight,
            child: i < bays.length
                ? _Bay(
                    slot: bays[i],
                    session: sessions[bays[i].slotCode],
                    compact: compact,
                    stallOnRight: alignRight,
                    onTap: onBayTap,
                  )
                : const _EmptyBay(),
          ),
        ],
      ],
    );

    return Container(
      width: widthFor(compact: compact),
      padding: const EdgeInsets.all(_padding),
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadii.mdAll,
        border: Border.all(color: t.border.subtle),
      ),
      child: Column(
        children: [
          _GateRow(gate: 1, top: true, health: health[1], compact: compact, onTap: () => onGateTap(1)),
          SizedBox(height: gap + 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              column(left, alignRight: false),
              SizedBox(
                width: _laneWidth(compact),
                height: bayHeight * _rows + gap * (_rows - 1),
                child: const _DriveLane(),
              ),
              column(right, alignRight: true),
            ],
          ),
          SizedBox(height: gap + 2),
          _GateRow(gate: 2, top: false, health: health[2], compact: compact, onTap: () => onGateTap(2)),
        ],
      ),
    );
  }
}

/// A barrier between two walls. The barrier
/// block carries the gate's device health in words and when its reader last
/// read a card; a red border means something there is down. Click it for the
/// gate's detail panel.
class _GateRow extends StatelessWidget {
  const _GateRow({
    required this.gate,
    required this.top,
    required this.health,
    required this.compact,
    required this.onTap,
  });

  final int gate;
  final bool top;
  final GateStatus? health;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final height = compact ? 58.0 : 66.0;
    final known = health?.known ?? false;
    final down = health?.anyDown ?? false;

    Widget wall() => Expanded(
      flex: 4,
      child: Tooltip(
        message: 'Wall — no entry',
        child: Container(
          height: height,
          clipBehavior: Clip.antiAlias,
          // Plain, not hatched: the hatch means "out of service" on a bay,
          // and a wall must not read as a broken one.
          decoration: BoxDecoration(
            color: t.border.normal,
            borderRadius: AppRadii.smAll,
          ),
        ),
      ),
    );

    final small = text.labelSmall?.copyWith(color: t.text.inverse);

    final barrier = Expanded(
      flex: 5,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
        child: Tooltip(
          message: 'Gate $gate — click for details',
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              onTap: onTap,
              child: AnimatedContainer(
                duration: AppMotion.normal,
                height: height,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x2),
                decoration: BoxDecoration(
                  color: t.surface.inverse,
                  borderRadius: AppRadii.smAll,
                  border: Border.all(
                    color: down ? t.status.danger.solid : t.surface.inverse,
                    width: 2,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          top ? Icons.south_rounded : Icons.north_rounded,
                          size: 14,
                          color: t.text.inverse,
                        ),
                        const SizedBox(width: AppSpacing.x1),
                        Flexible(
                          child: Text(
                            'GATE $gate',
                            overflow: TextOverflow.ellipsis,
                            style: text.labelSmall?.copyWith(
                              color: t.text.inverse,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _DeviceWord(label: 'Reader', ok: health?.reader),
                          const SizedBox(width: AppSpacing.x3),
                          _DeviceWord(label: 'Camera', ok: health?.camera),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      !known
                          ? 'Waiting for guard post'
                          : health?.relayed ?? false
                              ? 'Reported by guard post'
                              : 'Last tap ${ago(health?.lastTapAt)}',
                      overflow: TextOverflow.ellipsis,
                      style: small?.copyWith(color: t.text.inverseMuted, fontSize: 10),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return Row(children: [wall(), barrier, wall()]);
  }
}

/// "● Reader": the dot is green up, red down, grey unknown.
class _DeviceWord extends StatelessWidget {
  const _DeviceWord({required this.label, required this.ok, this.onDark = true});

  final String label;
  final bool? ok;

  /// On the black barrier block; false on a light card.
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: AppMotion.normal,
          width: 7,
          height: 7,
          decoration: BoxDecoration(shape: BoxShape.circle, color: deviceColor(context, ok)),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: ok == false ? t.status.danger.solid : (onDark ? t.text.inverse : t.text.secondary),
            fontWeight: ok == false ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// One small card per gate under GATE HEALTH, side by side when they fit.
class _GateTiles extends StatelessWidget {
  const _GateTiles({required this.health, required this.onTap});

  final Map<int, GateStatus> health;
  final void Function(int gate) onTap;

  @override
  Widget build(BuildContext context) {
    final gates = health.keys.toList()..sort();
    return LayoutBuilder(
      builder: (context, box) {
        final tiles = [for (final g in gates) _GateTile(status: health[g]!, onTap: () => onTap(g))];
        if (box.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(height: AppSpacing.x3),
                tiles[i],
              ],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < tiles.length; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.x3),
                Expanded(child: tiles[i]),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _GateTile extends StatefulWidget {
  const _GateTile({required this.status, required this.onTap});

  final GateStatus status;
  final VoidCallback onTap;

  @override
  State<_GateTile> createState() => _GateTileState();
}

/// One gate at a glance: is it working, which part isn't, and its last tap.
/// Today's traffic and the reader's port are one click away, in the details.
class _GateTileState extends State<_GateTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = widget.status;

    final (intent, word) = switch (s) {
      GateStatus(known: false) => (StatusIntent.neutral, 'Waiting'),
      GateStatus(reader: false, camera: false) => (StatusIntent.danger, 'Offline'),
      GateStatus(reader: false) => (StatusIntent.danger, 'Reader down'),
      GateStatus(camera: false) => (StatusIntent.warning, 'Camera down'),
      _ => (StatusIntent.success, 'Online'),
    };

    final detail = !s.known
        ? 'Waiting for the guard post'
        : s.readerError ?? (s.relayed ? 'Reported by guard post' : 'Last tap ${ago(s.lastTapAt)}');

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(AppSpacing.x4),
          decoration: BoxDecoration(
            color: t.surface.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: s.anyDown ? t.status.danger.border : (_hovered ? t.border.strong : t.border.subtle),
            ),
            boxShadow: _hovered ? AppElevation.md : AppElevation.none,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Gate ${s.gate}', style: text.titleMedium),
                  const SizedBox(width: AppSpacing.x2),
                  StatusPill(label: word, intent: intent, dense: true),
                  const Spacer(),
                  Icon(Icons.chevron_right, size: AppSizes.iconSm, color: t.text.tertiary),
                ],
              ),
              const SizedBox(height: AppSpacing.x3),
              Wrap(
                spacing: AppSpacing.x3,
                children: [
                  _DeviceWord(label: 'Reader', ok: s.reader, onDark: false),
                  _DeviceWord(label: 'Camera', ok: s.camera, onDark: false),
                ],
              ),
              const SizedBox(height: AppSpacing.x2),
              Text(
                detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.bodyMedium?.copyWith(
                  color: s.readerError != null ? t.status.danger.fg : t.text.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeviceChip extends StatelessWidget {
  const _DeviceChip({required this.label, required this.ok});

  final String label;
  final bool? ok;

  @override
  Widget build(BuildContext context) {
    return StatusPill(
      label: label,
      intent: switch (ok) {
        null => StatusIntent.neutral,
        true => StatusIntent.success,
        false => StatusIntent.danger,
      },
      dense: true,
    );
  }
}

class _DriveLane extends StatelessWidget {
  const _DriveLane();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      child: CustomPaint(
        painter: _LanePainter(color: t.border.normal),
        child: Center(
          child: RotatedBox(
            quarterTurns: 3,
            child: Text(
              'DRIVE LANE',
              style: text.labelSmall?.copyWith(
                color: t.text.tertiary,
                letterSpacing: 3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A dashed centre line with arrows both ways: either gate is in and out.
class _LanePainter extends CustomPainter {
  const _LanePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;

    // Dashes, leaving a gap mid-way for the label.
    final labelGap = 56.0;
    final mid = size.height / 2;
    for (double y = 22; y < size.height - 22; y += 14) {
      if ((y - mid).abs() < labelGap) continue;
      canvas.drawLine(Offset(x, y), Offset(x, (y + 7).clamp(0, size.height - 22)), paint);
    }

    void arrow(double y, bool down) {
      final d = down ? 1 : -1;
      final path = Path()
        ..moveTo(x - 6, y - 4 * d)
        ..lineTo(x, y + 4 * d)
        ..lineTo(x + 6, y - 4 * d);
      canvas.drawPath(path, paint..style = PaintingStyle.stroke);
    }

    arrow(10, true);
    arrow(size.height - 10, false);
  }

  @override
  bool shouldRepaint(_LanePainter old) => old.color != color;
}

/// One bay. Free is quiet — a plain bay with a green outline and dot — and
/// occupied fills solid coral, so the eye goes straight to the taken bays,
/// from across the guard house as much as on a monitor.
class _Bay extends StatefulWidget {
  const _Bay({
    required this.slot,
    required this.session,
    required this.compact,
    required this.stallOnRight,
    required this.onTap,
  });

  final ParkingSlot slot;
  final ActiveParkingSession? session;
  final bool compact;

  /// Right-column bays have their back wall on the right.
  final bool stallOnRight;

  final void Function(ParkingSlot slot)? onTap;

  @override
  State<_Bay> createState() => _BayState();
}

class _BayState extends State<_Bay> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final slot = widget.slot;
    final session = widget.session;
    // No sensor signal: shown grey, whatever it last read, until a linked
    // sensor is heard from again.
    final coverage = _Coverage.of(context);
    final silent = coverage.silent(slot);
    final c = silent ? t.status.neutral : t.status.of(StatusIntents.slot(slot.status));

    final occupied = !silent && slot.status == 'Occupied';
    final free = !silent && slot.status == 'Available';
    final outOfService = slot.status == 'OutOfService';
    final fg = occupied
        ? t.text.onBrand
        : free
            ? t.text.primary
            : c.fg;

    final tooltip = [
      silent
          ? '${slot.slotCode} · Sensor has no signal (last seen ${_statusLabel(slot.status).toLowerCase()})'
          : '${slot.slotCode} · ${_statusLabel(slot.status)}',
      slot.isMotorcycle ? 'Motorcycle bay' : slot.vehicleType == 'Car' ? 'Four-wheel bay' : 'Any vehicle',
      if (session != null) session.userName,
      if (session?.plateNumber != null) session!.plateNumber!,
      if (session != null) 'In since ${_clock.format(manila(session.entryTime))}',
      if (widget.onTap != null) 'Click to change status',
    ].join('\n');

    // With no bay heard from, the banner above the map says so once; each
    // bay keeps its vehicle icon instead of repeating it eighteen times.
    final icon = Icon(
      silent && !coverage.none ? Icons.sensors_off_rounded : switch (slot.vehicleType) {
        'Motorcycle' => Icons.two_wheeler_rounded,
        'Car' => Icons.directions_car_rounded,
        _ => Icons.local_parking_rounded,
      },
      size: widget.compact ? 16 : 20,
      color: free ? t.text.secondary : fg,
    );

    final label = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: widget.stallOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // The one spot of green on a free bay: enough to say "free"
            // without turning an empty lot into a wall of colour.
            if (free) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: c.solid),
              ),
              const SizedBox(width: AppSpacing.x2),
            ],
            Flexible(
              child: Text(
                _shortCode(slot.slotCode),
                overflow: TextOverflow.ellipsis,
                style: AppTypography.tabular(
                  (widget.compact ? text.titleSmall : text.titleMedium)!.copyWith(
                    color: fg,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (!widget.compact && session != null)
          Text(
            session.plateNumber ?? session.userName,
            overflow: TextOverflow.ellipsis,
            style: text.labelSmall?.copyWith(color: fg.withValues(alpha: 0.85)),
          ),
      ],
    );

    final tile = AnimatedContainer(
      duration: AppMotion.slow,
      curve: AppMotion.standard,
      clipBehavior: Clip.antiAlias,
      padding: EdgeInsets.symmetric(horizontal: widget.compact ? AppSpacing.x2 : AppSpacing.x3),
      decoration: BoxDecoration(
        color: occupied
            ? c.solid
            : free
                ? t.surface.card
                : c.bg,
        borderRadius: AppRadii.smAll,
        border: Border.all(
          color: _hovered ? c.solid : (occupied ? c.solid : c.border),
          width: _hovered ? 2 : 1.25,
        ),
        boxShadow: _hovered ? AppElevation.md : AppElevation.none,
      ),
      child: Stack(
        children: [
          if (outOfService) AppHatchPattern(color: c.border, spacing: 8),
          Row(
            children: widget.stallOnRight
                ? [icon, const SizedBox(width: AppSpacing.x2), Expanded(child: label)]
                : [Expanded(child: label), const SizedBox(width: AppSpacing.x2), icon],
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: widget.onTap == null ? MouseCursor.defer : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap == null ? null : () => widget.onTap!(slot),
        child: Tooltip(message: tooltip, child: tile),
      ),
    );
  }
}

/// A painted bay with no slot set up for it yet.
class _EmptyBay extends StatelessWidget {
  const _EmptyBay();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Tooltip(
      message: 'No bay set up here',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: AppRadii.smAll,
          border: Border.all(color: t.border.subtle),
        ),
        alignment: Alignment.center,
        child: Text('—', style: TextStyle(color: t.text.disabled)),
      ),
    );
  }
}

class _Unplaced extends StatelessWidget {
  const _Unplaced({required this.slots, required this.sessions, required this.onBayTap});

  final List<ParkingSlot> slots;
  final Map<String, ActiveParkingSession> sessions;
  final void Function(ParkingSlot slot)? onBayTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'NOT ON THE MAP (${slots.length})',
          style: text.labelSmall?.copyWith(
            color: t.text.tertiary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: AppSpacing.labelGap),
        Text(
          'Each side of the model holds nine bays. These are beyond that.',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(height: AppSpacing.x3),
        Wrap(
          spacing: AppSpacing.x2,
          runSpacing: AppSpacing.x2,
          children: [
            for (final s in slots)
              SizedBox(
                width: 110,
                height: 36,
                child: _Bay(
                  slot: s,
                  session: sessions[s.slotCode],
                  compact: true,
                  stallOnRight: false,
                  onTap: onBayTap,
                ),
              ),
          ],
        ),
      ],
    );
  }
}

// ── Numbers beside the map ───────────────────────────────────────────────────

class _Summary extends StatelessWidget {
  const _Summary({required this.slots, required this.availability});

  final List<ParkingSlot> slots;
  final ParkingAvailability availability;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    // The count is cars inside the lot, from the server: a car that tapped in
    // counts until it taps out, even while its bay shows green (driving to it,
    // parked elsewhere, lifted out of the model).
    // Bays no live sensor vouches for are neither free nor taken: they are
    // left out of both, and counted on their own.
    final coverage = _Coverage.of(context);
    final usable = slots.where((s) => s.status != 'OutOfService').toList();
    final free = coverage.free(usable, availability.availableSlots);
    final noSignal = usable.where(coverage.silent).length;
    final occupied = (usable.length - free - noSignal).clamp(0, usable.length);
    final down = slots.length - usable.length;
    // Cars that tapped in but no sensor sees in a bay yet — driving to one,
    // or parked off the model. Said out loud, so a "16 free" over a map of
    // eighteen green bays doesn't look like a bug.
    final inBays = usable.where((s) => s.status == 'Occupied' && coverage.confirms(s)).length;
    final notInBay = (occupied - inBays).clamp(0, occupied);
    final ratio = usable.isEmpty ? 0.0 : occupied / usable.length;

    final intent = switch (ratio) {
      _ when usable.isNotEmpty && noSignal == usable.length => StatusIntent.neutral,
      >= 0.95 => StatusIntent.danger,
      >= 0.8 => StatusIntent.warning,
      _ => StatusIntent.success,
    };

    final note = AppTypography.tabular(text.bodyMedium!.copyWith(color: t.text.secondary));

    final occupancy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('OCCUPANCY', style: _eyebrow(context)),
        const SizedBox(height: AppSpacing.x2),
        Text.rich(
          TextSpan(
            text: '$free',
            style: AppTypography.tabular(text.displayMedium!.copyWith(color: t.status.of(intent).fg)),
            children: [
              TextSpan(
                text: ' / ${usable.length} free',
                style: text.titleMedium?.copyWith(color: t.text.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        ClipRRect(
          borderRadius: AppRadii.fullAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 10,
            backgroundColor: t.surface.muted,
            valueColor: AlwaysStoppedAnimation(t.status.of(intent).solid),
          ),
        ),
        const SizedBox(height: AppSpacing.x2),
        Text('$occupied taken · ${(ratio * 100).round()}% full', style: note),
        if (notInBay > 0) ...[
          const SizedBox(height: AppSpacing.x1),
          Text(
            notInBay == 1
                ? '1 car inside not yet in a bay'
                : '$notInBay cars inside not yet in a bay',
            style: note,
          ),
        ],
        if (noSignal > 0) ...[
          const SizedBox(height: AppSpacing.x1),
          Row(
            children: [
              Icon(Icons.sensors_off_rounded, size: AppSizes.iconSm, color: t.status.neutral.fg),
              const SizedBox(width: AppSpacing.x2),
              Text('$noSignal with no sensor signal', style: note),
            ],
          ),
        ],
      ],
    );

    final vehicles = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('VEHICLES', style: _eyebrow(context)),
        const SizedBox(height: AppSpacing.x3),
        _FreeRow(
          icon: Icons.directions_car_rounded,
          label: 'Four-wheel',
          counts: coverage.freeOf(usable.where((s) => s.vehicleType == 'Car'), availability.availableCars),
        ),
        _FreeRow(
          icon: Icons.two_wheeler_rounded,
          label: 'Motorcycle',
          counts: coverage.freeOf(
            usable.where((s) => s.vehicleType != 'Car'),
            availability.availableMotorcycles,
          ),
        ),
        if (down > 0) ...[
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Icon(Icons.block, size: AppSizes.iconSm, color: t.status.danger.fg),
              const SizedBox(width: AppSpacing.x2),
              Text(
                '$down out of service',
                style: text.bodyMedium?.copyWith(color: t.status.danger.fg),
              ),
            ],
          ),
        ],
      ],
    );

    return LayoutBuilder(
      builder: (context, box) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Side by side when the panel is wide, so the numbers spread over
          // the space instead of running down one narrow strip.
          if (box.maxWidth >= 620)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: occupancy),
                const SizedBox(width: AppSpacing.x8),
                Expanded(child: vehicles),
              ],
            )
          else ...[
            occupancy,
            const SizedBox(height: AppSpacing.x6),
            vehicles,
          ],
          const SizedBox(height: AppSpacing.x5),
          const _Legend(),
        ],
      ),
    );
  }
}

TextStyle? _eyebrow(BuildContext context) => Theme.of(context).textTheme.labelSmall?.copyWith(
  color: context.tokens.text.tertiary,
  fontWeight: FontWeight.w600,
  letterSpacing: 0.8,
);

class _FreeRow extends StatelessWidget {
  const _FreeRow({required this.icon, required this.label, required this.counts});

  final IconData icon;
  final String label;
  final (int free, int total, int noSignal) counts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (free, total, noSignal) = counts;
    // The bar is the bays a sensor sees taken. Bays with no signal are not
    // taken, and must not paint the lot red as if it were full.
    final taken = (total - free - noSignal).clamp(0, total);
    final ratio = total == 0 ? 0.0 : taken / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x2),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconMd, color: t.text.secondary),
          const SizedBox(width: AppSpacing.x2),
          SizedBox(width: 104, child: Text(label, style: text.bodyMedium)),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.fullAll,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 8,
                backgroundColor: t.surface.muted,
                valueColor: AlwaysStoppedAnimation(
                  t.status.of(free == 0 && taken > 0 ? StatusIntent.danger : StatusIntent.accent).solid,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          SizedBox(
            width: 112,
            child: Text(
              noSignal > 0 ? '$free / $total free\n$noSignal no signal' : '$free / $total free',
              textAlign: TextAlign.right,
              style: AppTypography.tabular(text.bodyMedium!.copyWith(color: t.text.secondary)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    Widget entry(String status, String label, {bool filled = false}) {
      final c = t.status.of(StatusIntents.slot(status));
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 10,
            decoration: BoxDecoration(
              color: filled
                  ? c.solid
                  : status == 'Available'
                      ? t.surface.card
                      : c.bg,
              border: Border.all(color: filled ? c.solid : c.border, width: 1.25),
              borderRadius: const BorderRadius.all(Radius.circular(3)),
            ),
          ),
          const SizedBox(width: AppSpacing.x2 - 2),
          Text(label, style: text.labelSmall?.copyWith(color: t.text.secondary)),
        ],
      );
    }

    return Wrap(
      spacing: AppSpacing.x4,
      runSpacing: AppSpacing.x2,
      children: [
        entry('Available', 'Free'),
        entry('Occupied', 'Occupied', filled: true),
        entry('OutOfService', 'Out of service'),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sensors_off_rounded, size: 12, color: t.status.neutral.fg),
            const SizedBox(width: AppSpacing.x2 - 2),
            Text('No sensor signal', style: text.labelSmall?.copyWith(color: t.text.secondary)),
          ],
        ),
      ],
    );
  }
}

/// "G1-C1" → "C1", for a server whose bays still carry the old gate prefix.
/// Bays are now numbered across the whole lot (C1–C6, M1–M12), where this
/// changes nothing.
String _shortCode(String code) => code.replaceFirst(RegExp(r'^G\d+-'), '');

String _statusLabel(String status) => switch (status) {
  'Available' => 'Free',
  'OutOfService' => 'Out of service',
  _ => status,
};


/// Which bays a live sensor vouches for right now.
///
/// A bay reads free or taken only while a sensor linked to it is online.
/// Every other usable bay is "No sensor signal" — the hub unplugged, its
/// board off, or no sensor ever linked to it — so a lot nobody can see never
/// passes for an empty one.
class _SensorCoverage {
  const _SensorCoverage(this.live);

  /// No device list reached this panel (a guard post too old to send one):
  /// bays show what the server says, as they always did.
  static const unknown = _SensorCoverage(null);

  /// `<gate>|<slot code>` of each bay a bound, online sensor watches.
  final Set<String>? live;

  /// At the guard post its own server lists the devices; online, the cloud
  /// relays the same list.
  factory _SensorCoverage.from(DeviceHealthState local, SiteLink? link) {
    if (local.report case final report?) return _SensorCoverage.of(report.devices);
    if (link != null && link.reportsHealth) return _SensorCoverage.of(link.devices);
    // Still finding out where this panel is (no answer from either yet):
    // grey until a sensor is heard from, never green on a guess.
    if (local.atGuardPost && link == null) return const _SensorCoverage({});
    return unknown;
  }

  /// A sensor names its bay as "Slot G1-C4 (Gate 1)". Both gates have a C4,
  /// so the gate is part of the key.
  factory _SensorCoverage.of(List<DeviceHealth> devices) => _SensorCoverage({
        for (final d in devices)
          if (d.kind == 'slotSensor' && d.bound && d.online && d.boundTo != null)
            if (RegExp(r'^Slot (.+) \(Gate (\d+)\)$').firstMatch(d.boundTo!) case final m?)
              _key(int.parse(m.group(2)!), m.group(1)!),
      });

  static String _key(int gate, String slotCode) => '$gate|$slotCode';

  bool confirms(ParkingSlot s) => live?.contains(_key(s.gate, s.slotCode)) ?? true;

  /// A device list came, and no bay has a live sensor in it.
  bool get none => live?.isEmpty ?? false;

  /// Out-of-service bays keep their own look: someone closed them on purpose.
  bool silent(ParkingSlot s) => s.status != 'OutOfService' && !confirms(s);

  /// Free bays in [group]: the server's count, from cars tapped in and out,
  /// but never more than the bays a live sensor sees empty.
  int free(List<ParkingSlot> group, int? fromServer) {
    final seenFree = group.where((s) => s.status == 'Available' && confirms(s)).length;
    final free = fromServer ?? seenFree;
    return (live == null ? free : min(free, seenFree)).clamp(0, group.length);
  }

  /// Free, total and no-signal bays in [group], for one vehicle type.
  (int, int, int) freeOf(Iterable<ParkingSlot> group, int? fromServer) {
    final bays = group.toList();
    return (free(bays, fromServer), bays.length, bays.where(silent).length);
  }

  /// Usable bays vouched for, of all of them, for the header badge.
  (int, int)? count(List<ParkingSlot>? slots) {
    if (live == null || slots == null) return null;
    final usable = slots.where((s) => s.status != 'OutOfService').toList();
    return (usable.where(confirms).length, usable.length);
  }
}

/// The sensor coverage, for every bay on the map to read without passing it
/// down through each layer.
class _Coverage extends InheritedWidget {
  const _Coverage({required this.coverage, required super.child});

  final _SensorCoverage coverage;

  static _SensorCoverage of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Coverage>()?.coverage ?? _SensorCoverage.unknown;

  @override
  bool updateShouldNotify(_Coverage old) {
    final (a, b) = (old.coverage.live, coverage.live);
    return a == null || b == null ? a != b : a.length != b.length || !a.containsAll(b);
  }
}
