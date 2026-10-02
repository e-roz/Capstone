import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/network/dio_client.dart';
import '../../models/parking_slot.dart';
import '../../providers/parking_provider.dart';
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
class LiveParkingMapCard extends ConsumerStatefulWidget {
  const LiveParkingMapCard({
    super.key,
    this.compact = false,
    this.onBayTap,
    this.showOpenLink = false,
  });

  /// Smaller bays and no plate on them; for the overview screens.
  final bool compact;

  /// Called when a bay is clicked, e.g. to change its status. Null = read-only.
  final void Function(ParkingSlot slot)? onBayTap;

  /// Adds an "Open map" link to the full Parking screen.
  final bool showOpenLink;

  @override
  ConsumerState<LiveParkingMapCard> createState() => _LiveParkingMapCardState();
}

class _LiveParkingMapCardState extends ConsumerState<LiveParkingMapCard> {
  // A car leaving should free its bay on screen within a second or two.
  static const _refreshEvery = Duration(milliseconds: 1500);
  static const _healthEvery = Duration(seconds: 5);

  Timer? _timer;
  Timer? _ticker;
  Timer? _healthTimer;
  DateTime? _updatedAt;

  bool _healthInFlight = false;
  Map<int, GateStatus> _health = const {1: GateStatus.unknown1, 2: GateStatus.unknown2};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(_refreshEvery, (_) => _refresh());
    _checkHealth();
    _healthTimer = Timer.periodic(_healthEvery, (_) => _checkHealth());
    // Keeps "updated 2s ago" honest between refreshes.
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ticker?.cancel();
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

  void _showGate(int gate) => showGateDetails(
    context,
    status: _health[gate] ?? GateStatus(gate: gate, known: false),
    dio: ref.read(dioProvider),
  );

  void _refresh() {
    // A refresh still in flight is left to finish rather than stacked.
    if (ref.read(parkingSlotsProvider).isLoading) return;
    ref.invalidate(parkingSlotsProvider);
    ref.invalidate(activeParkingSessionsProvider);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(parkingSlotsProvider, (_, next) {
      if (next.hasValue && !next.isLoading) _updatedAt = DateTime.now();
    });

    final slots = ref.watch(parkingSlotsProvider);
    final sessions = {
      for (final s in ref.watch(activeParkingSessionsProvider).valueOrNull ??
          const <ActiveParkingSession>[])
        if (s.slotCode != null) s.slotCode!: s,
    };

    return AppSectionCard(
      title: 'Live parking map',
      subtitle: 'Live bay status, refreshed every few seconds.',
      icon: Icons.local_parking_outlined,
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      actions: [
        _LiveBadge(updatedAt: _updatedAt, failing: slots.hasError),
        if (widget.showOpenLink)
          TextButton(
            onPressed: () => context.go('/parking'),
            child: const Text('Open map'),
          ),
      ],
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
        data: (availability) => _MapWithSummary(
          slots: availability.slots,
          sessions: sessions,
          compact: widget.compact,
          onBayTap: widget.onBayTap,
          health: _health,
          onGateTap: _showGate,
        ),
      ),
    );
  }
}

// ── Header badge ─────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  const _LiveBadge({required this.updatedAt, required this.failing});

  final DateTime? updatedAt;
  final bool failing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(failing ? StatusIntent.warning : StatusIntent.success);

    final age = updatedAt == null ? null : DateTime.now().difference(updatedAt!);
    final label = failing
        ? 'Reconnecting'
        : age == null
        ? 'Live'
        : age.inSeconds < 2
        ? 'Live · just now'
        : 'Live · ${age.inSeconds}s ago';

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
          _PulseDot(color: c.solid),
          const SizedBox(width: AppSpacing.x2),
          Text(label, style: AppTypography.tabular(text.labelSmall!.copyWith(color: c.fg))),
        ],
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
    required this.sessions,
    required this.compact,
    required this.onBayTap,
    required this.health,
    required this.onGateTap,
  });

  final List<ParkingSlot> slots;
  final Map<String, ActiveParkingSession> sessions;
  final bool compact;
  final void Function(ParkingSlot slot)? onBayTap;
  final Map<int, GateStatus> health;
  final void Function(int gate) onGateTap;

  @override
  Widget build(BuildContext context) {
    final left = _column(gate: 1, carsLast: false);
    final right = _column(gate: 2, carsLast: true);

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
    final summary = _Summary(slots: slots);

    return LayoutBuilder(
      builder: (context, box) {
        final sideBySide = box.maxWidth >= 860;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sideBySide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 3, child: map),
                  const SizedBox(width: AppSpacing.x6),
                  Expanded(flex: 2, child: summary),
                ],
              )
            else ...[
              map,
              const SizedBox(height: AppSpacing.x5),
              summary,
            ],
            const SizedBox(height: AppSpacing.x5),
            _GateTiles(health: health, onTap: onGateTap),
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
  /// top of the left column and at the bottom of the right one. When a gate
  /// has more than nine bays, the overflow comes from the non-car bays, so the
  /// four-wheel bays always keep their painted spots at the end of the column.
  List<ParkingSlot> _column({required int gate, required bool carsLast}) {
    int byCode(ParkingSlot a, ParkingSlot b) => _naturalCompare(a.slotCode, b.slotCode);
    final atGate = slots.where((s) => s.gate == gate).toList();
    final cars = (atGate.where((s) => s.vehicleType == 'Car').toList()..sort(byCode)).take(_rows).toList();
    final others = (atGate.where((s) => s.vehicleType != 'Car').toList()..sort(byCode))
        .take(_rows - cars.length)
        .toList();
    return carsLast ? [...others, ...cars] : [...cars, ...others];
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bayHeight = compact ? 34.0 : 44.0;
    final gap = compact ? AppSpacing.x1 + 2 : AppSpacing.x2;

    Widget column(List<ParkingSlot> bays, {required bool alignRight}) => Column(
      children: [
        for (var i = 0; i < _rows; i++) ...[
          if (i > 0) SizedBox(height: gap),
          SizedBox(
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
      padding: const EdgeInsets.all(AppSpacing.x3),
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
              Expanded(flex: 5, child: column(left, alignRight: false)),
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: bayHeight * _rows + gap * (_rows - 1),
                  child: const _DriveLane(),
                ),
              ),
              Expanded(flex: 5, child: column(right, alignRight: true)),
            ],
          ),
          SizedBox(height: gap + 2),
          _GateRow(gate: 2, top: false, health: health[2], compact: compact, onTap: () => onGateTap(2)),
        ],
      ),
    );
  }
}

/// A barrier between two walls — the blueprint's red crosses. The barrier
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
          decoration: BoxDecoration(
            color: t.surface.card,
            borderRadius: AppRadii.smAll,
            border: Border.all(color: t.border.normal),
          ),
          child: Stack(
            children: [
              AppHatchPattern(color: t.border.strong, spacing: 7),
            ],
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
                      known ? 'Last tap ${ago(health?.lastTapAt)}' : 'Status from guard post only',
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
  const _DeviceWord({required this.label, required this.ok});

  final String label;
  final bool? ok;

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
            color: ok == false ? t.status.danger.solid : t.text.inverse,
            fontWeight: ok == false ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// One tile per gate under the map: which reader on which port, why it's
/// down, today's traffic and the last thing that happened there.
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
        if (box.maxWidth < 640) {
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

class _GateTileState extends State<_GateTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final s = widget.status;
    final secondary = text.bodySmall?.copyWith(color: t.text.secondary);
    final last = s.last;

    final readerLine = [
      s.readerName ?? 'Reader',
      if (s.port != null) s.port!,
    ].join(' · ');

    Widget line(IconData icon, Widget child) => Padding(
      padding: const EdgeInsets.only(top: AppSpacing.x2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: AppSizes.iconSm, color: t.text.tertiary),
          const SizedBox(width: AppSpacing.x2),
          Expanded(child: child),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.fast,
          padding: const EdgeInsets.all(AppSpacing.x3),
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
                  Text('Gate ${s.gate}', style: text.titleSmall),
                  const Spacer(),
                  _DeviceChip(label: 'Reader', ok: s.reader),
                  const SizedBox(width: AppSpacing.x2),
                  _DeviceChip(label: 'Camera', ok: s.camera),
                  const SizedBox(width: AppSpacing.x1),
                  Icon(Icons.chevron_right, size: AppSizes.iconSm, color: t.text.tertiary),
                ],
              ),
              if (!s.known)
                line(
                  Icons.info_outline,
                  Text("Open the panel at the guard post to see this gate's devices and log.", style: secondary),
                )
              else ...[
                // 3 + 4: which reader, and why it's down.
                line(
                  Icons.contactless_outlined,
                  Text.rich(
                    TextSpan(
                      text: readerLine,
                      style: text.bodySmall,
                      children: [
                        if (s.readerError != null)
                          TextSpan(
                            text: '  ${s.readerError}',
                            style: text.bodySmall?.copyWith(color: t.status.danger.fg, fontWeight: FontWeight.w600),
                          )
                        else
                          TextSpan(text: '  · last tap ${ago(s.lastTapAt)}', style: secondary),
                      ],
                    ),
                  ),
                ),
                // 5: today's traffic.
                line(
                  Icons.swap_vert_rounded,
                  Text.rich(
                    TextSpan(
                      style: AppTypography.tabular(text.bodySmall!),
                      children: [
                        TextSpan(text: '${s.entered}${s.countsCapped ? '+' : ''} in'),
                        TextSpan(text: '  ·  ', style: secondary),
                        TextSpan(text: '${s.exited}${s.countsCapped ? '+' : ''} out'),
                        TextSpan(text: '  ·  ', style: secondary),
                        TextSpan(
                          text: '${s.refused}${s.countsCapped ? '+' : ''} refused',
                          style: s.refused > 0
                              ? TextStyle(color: t.status.danger.fg, fontWeight: FontWeight.w600)
                              : null,
                        ),
                        TextSpan(text: '  today', style: secondary),
                      ],
                    ),
                  ),
                ),
                // 6: the last thing that happened here.
                line(
                  Icons.history_rounded,
                  last == null
                      ? Text('No taps today', style: secondary)
                      : Text(
                          lastEventLine(last),
                          overflow: TextOverflow.ellipsis,
                          style: text.bodySmall?.copyWith(
                            color: last.opened ? t.text.primary : t.status.danger.fg,
                            fontWeight: last.opened ? null : FontWeight.w600,
                          ),
                        ),
                ),
              ],
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

/// One bay. Free is a soft green outline; occupied fills solid, so the change
/// reads from across the guard house.
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
    final c = t.status.of(StatusIntents.slot(slot.status));

    final occupied = slot.status == 'Occupied';
    final outOfService = slot.status == 'OutOfService';
    final fg = occupied ? t.text.onBrand : c.fg;

    final tooltip = [
      '${slot.slotCode} · ${_statusLabel(slot.status)}',
      slot.isMotorcycle ? 'Motorcycle bay' : slot.vehicleType == 'Car' ? 'Four-wheel bay' : 'Any vehicle',
      if (session != null) session.userName,
      if (session?.plateNumber != null) session!.plateNumber!,
      if (session != null) 'In since ${_clock.format(session.entryTime.toLocal())}',
      if (widget.onTap != null) 'Click to change status',
    ].join('\n');

    final icon = Icon(
      switch (slot.vehicleType) {
        'Motorcycle' => Icons.two_wheeler_rounded,
        'Car' => Icons.directions_car_rounded,
        _ => Icons.local_parking_rounded,
      },
      size: widget.compact ? 14 : 16,
      color: fg,
    );

    final label = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: widget.stallOnRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          _shortCode(slot.slotCode),
          overflow: TextOverflow.ellipsis,
          style: AppTypography.tabular(
            (widget.compact ? text.labelMedium : text.titleSmall)!.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
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
        color: occupied ? c.solid : c.bg,
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
  const _Summary({required this.slots});

  final List<ParkingSlot> slots;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final usable = slots.where((s) => s.status != 'OutOfService').toList();
    final free = usable.where((s) => s.status == 'Available').length;
    final occupied = usable.where((s) => s.status == 'Occupied').length;
    final down = slots.length - usable.length;
    final ratio = usable.isEmpty ? 0.0 : occupied / usable.length;

    final intent = switch (ratio) {
      >= 0.95 => StatusIntent.danger,
      >= 0.8 => StatusIntent.warning,
      _ => StatusIntent.success,
    };

    (int, int) freeOf(bool Function(ParkingSlot) where) {
      final group = usable.where(where).toList();
      return (group.where((s) => s.status == 'Available').length, group.length);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('FREE NOW', style: _eyebrow(context)),
        const SizedBox(height: AppSpacing.x1),
        Text.rich(
          TextSpan(
            text: '$free',
            style: AppTypography.tabular(text.displaySmall!.copyWith(color: t.status.of(intent).fg)),
            children: [
              TextSpan(
                text: '  of ${usable.length} bays',
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.x3),
        ClipRRect(
          borderRadius: AppRadii.fullAll,
          child: LinearProgressIndicator(
            value: ratio,
            minHeight: 8,
            backgroundColor: t.surface.muted,
            valueColor: AlwaysStoppedAnimation(t.status.of(intent).solid),
          ),
        ),
        const SizedBox(height: AppSpacing.x1),
        Text(
          '$occupied occupied · ${(ratio * 100).round()}% full',
          style: AppTypography.tabular(text.bodySmall!.copyWith(color: t.text.secondary)),
        ),
        const SizedBox(height: AppSpacing.x5),
        Text('BY VEHICLE', style: _eyebrow(context)),
        const SizedBox(height: AppSpacing.x2),
        _FreeRow(
          icon: Icons.directions_car_rounded,
          label: 'Four-wheel',
          counts: freeOf((s) => s.vehicleType == 'Car'),
        ),
        _FreeRow(
          icon: Icons.two_wheeler_rounded,
          label: 'Motorcycle',
          counts: freeOf((s) => s.vehicleType != 'Car'),
        ),
        if (down > 0) ...[
          const SizedBox(height: AppSpacing.x3),
          Row(
            children: [
              Icon(Icons.block, size: AppSizes.iconSm, color: t.status.danger.fg),
              const SizedBox(width: AppSpacing.x2),
              Text(
                '$down out of service',
                style: text.bodySmall?.copyWith(color: t.status.danger.fg),
              ),
            ],
          ),
        ],
        const SizedBox(height: AppSpacing.x5),
        const _Legend(),
      ],
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
  final (int free, int total) counts;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final (free, total) = counts;
    final ratio = total == 0 ? 0.0 : (total - free) / total;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
      child: Row(
        children: [
          Icon(icon, size: AppSizes.iconSm, color: t.text.secondary),
          const SizedBox(width: AppSpacing.x2),
          SizedBox(width: 92, child: Text(label, style: text.bodySmall)),
          Expanded(
            child: ClipRRect(
              borderRadius: AppRadii.fullAll,
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: t.surface.muted,
                valueColor: AlwaysStoppedAnimation(
                  t.status.of(free == 0 && total > 0 ? StatusIntent.danger : StatusIntent.accent).solid,
                ),
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          SizedBox(
            width: 92,
            child: Text(
              '$free / $total free',
              textAlign: TextAlign.right,
              style: AppTypography.tabular(text.bodySmall!.copyWith(color: t.text.secondary)),
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
              color: filled ? c.solid : c.bg,
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
      ],
    );
  }
}

/// "G1-C1" → "C1". The gate prefix names the device the bay sits behind; it
/// isn't painted on the bay.
String _shortCode(String code) => code.replaceFirst(RegExp(r'^G\d+-'), '');

String _statusLabel(String status) => switch (status) {
  'Available' => 'Free',
  'OutOfService' => 'Out of service',
  _ => status,
};
