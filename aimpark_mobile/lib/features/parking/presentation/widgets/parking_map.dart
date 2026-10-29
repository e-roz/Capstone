import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/parking_slot.dart';
import '../../domain/lot_layout.dart';

/// How one bay reads on the map.
///
/// Deliberately not [StatusIntents.slot]: that maps `occupied` to the brand tone,
/// and the map keeps the one brand colour for the suggested bay.
///
/// "Yours" is only ever the bay the driver said they parked in. The lot's
/// sensors know which bays have a car in them, never whose, so the map cannot
/// work it out for them.
enum BayState {
  free,
  taken,
  outOfService,
  noSignal,
  suggested,
  confirmed;

  static BayState of(
    ParkingSlot slot, {
    String? suggestedCode,
    String? confirmedCode,
  }) {
    if (confirmedCode != null && slot.slotCode == confirmedCode) {
      return confirmed;
    }
    if (suggestedCode != null && slot.slotCode == suggestedCode) {
      return suggested;
    }
    return switch (slot.status.toLowerCase()) {
      'available' => free,
      'occupied' => taken,
      'nosignal' => noSignal,
      // Anything this app does not recognise is treated as unusable rather than
      // guessed to be free.
      _ => outOfService,
    };
  }

  String get label => switch (this) {
    BayState.free => 'Free',
    BayState.taken => 'Taken',
    BayState.outOfService => 'Out of service',
    BayState.noSignal => 'No signal',
    BayState.suggested => 'Suggested',
    BayState.confirmed => 'Your bay',
  };
}

/// The lot, drawn the way it is built.
///
/// Two columns of nine bays facing each other across a drive lane, Gate 1's
/// barrier at the top and Gate 2's at the bottom, and walls in the corners — the
/// same drawing the admin and guard-post screens use, so a driver and a guard are
/// looking at the same lot. Bays are placed by [LotLayout].
///
/// Every bay is shown, always, including when the lot is full: a full lot is
/// still something to look at, and the first bay to turn free appears here.
///
/// What it deliberately leaves out compared with the staff map: plates on bays
/// (nobody else's business), the gates' reader and camera health, and changing a
/// bay's status.
///
/// A bay is a button. Tapping one opens a small sheet saying what it is.
///
/// When [onConfirmSlot] is given the sheet also offers to record that the driver
/// parked there. A bay the sensor calls taken stays confirmable: sensors
/// sometimes report a car that is not there, and the driver's word is what the
/// guards rely on.
///
/// If the account has only one kind of vehicle, bays for the other kind are
/// dimmed rather than hidden — the lot stays whole and the driver's own bays are
/// the ones that stand out.
///
/// A bay for the other kind from the vehicle that came in
/// ([cameInOnMotorcycle]) cannot be confirmed: a motorcycle is not confirmed
/// into a car bay, nor a car into a motorcycle bay.
class ParkingMap extends StatelessWidget {
  const ParkingMap({
    super.key,
    required this.availability,
    this.suggestedCode,
    this.confirmedCode,
    this.onConfirmSlot,
    this.userHasCar = false,
    this.userHasMotorcycle = false,
    this.cameInOnMotorcycle,
  });

  final ParkingAvailability availability;

  /// The bay the server suggested, if they asked.
  final String? suggestedCode;

  /// The bay the driver has said they are parked in, if they have.
  final String? confirmedCode;

  /// Records that the driver parked in the given bay. Returns whether it
  /// worked; the caller shows any error itself. Null hides the confirm button.
  final Future<bool> Function(ParkingSlot slot)? onConfirmSlot;

  final bool userHasCar;
  final bool userHasMotorcycle;

  /// What came in for the session being confirmed: true for a motorcycle,
  /// false for a car. Null when it is not known yet, and the caller asks the
  /// driver before confirming.
  final bool? cameInOnMotorcycle;

  static const double _bayHeight = 56;
  static const double _gap = 8;
  static const double _lane = 40;
  static const double _pad = 12;

  /// Exactly one kind of vehicle on the account. With both, or neither, there is
  /// no kind of bay to prefer.
  bool get _knowsOneKind => userHasCar != userHasMotorcycle;

  /// The kind of vehicle the bays are judged against: what came in, else the
  /// only kind on the account. Null when there is nothing to go by.
  bool? get _kind =>
      cameInOnMotorcycle ?? (_knowsOneKind ? userHasMotorcycle : null);

  bool _isDimmed(ParkingSlot slot, BayState state) {
    final kind = _kind;
    if (kind == null) return false;
    // A bay that is already greyed out — out of service, or silent — is not faded
    // a second time for being the wrong kind. Two fades on top of each other and
    // the bay is gone, which is exactly what happened when the whole lot went
    // quiet.
    if (state != BayState.free && state != BayState.taken) return false;
    return !slot.takes(motorcycle: kind);
  }

  void _openSheet(BuildContext context, ParkingSlot slot, BayState state) {
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => _BaySheet(
        slot: slot,
        state: state,
        onConfirm: onConfirmSlot,
        wrongKindFor: _isDimmed(slot, state)
            ? (_kind! ? 'motorcycle' : 'car')
            : null,
        refusedFor: onConfirmSlot != null &&
                cameInOnMotorcycle != null &&
                !slot.takes(motorcycle: cameInOnMotorcycle!)
            ? (cameInOnMotorcycle! ? 'motorcycle' : 'car')
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final layout = LotLayout.of(availability.slots);

    Widget bay(ParkingSlot slot, {required bool mirrored, required double w}) {
      final state = BayState.of(
        slot,
        suggestedCode: suggestedCode,
        confirmedCode: confirmedCode,
      );
      return _Bay(
        slot: slot,
        state: state,
        mirrored: mirrored,
        width: w,
        height: _bayHeight,
        dimmed: _isDimmed(slot, state),
        onTap: () => _openSheet(context, slot, state),
      );
    }

    Widget column(
      List<ParkingSlot> bays, {
      required bool mirrored,
      required double w,
    }) {
      return Column(
        children: [
          for (var i = 0; i < LotLayout.rows; i++) ...[
            if (i > 0) const SizedBox(height: _gap),
            if (i < bays.length)
              bay(bays[i], mirrored: mirrored, w: w)
            else
              SizedBox(width: w, height: _bayHeight),
          ],
        ],
      );
    }

    final columnHeight =
        LotLayout.rows * _bayHeight + (LotLayout.rows - 1) * _gap;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Less the card's own 1px border on each side, or the two columns are
        // two points too wide for the row they sit in.
        final bayW = (constraints.maxWidth - 2 - _pad * 2 - _lane) / 2;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                color: t.surface.card,
                borderRadius: AppRadius.lgAll,
                border: Border.all(color: t.border.normal),
              ),
              child: Column(
                children: [
                  const _GateRow(gate: 1, entersDownward: true),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      column(layout.left, mirrored: false, w: bayW),
                      _Lane(height: columnHeight),
                      column(layout.right, mirrored: true, w: bayW),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const _GateRow(gate: 2, entersDownward: false),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _Legend(
              showSuggested: suggestedCode != null,
              showConfirmed: confirmedCode != null,
            ),
            // Bays the drawing has no room for are listed rather than dropped.
            if (layout.unplaced.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              const AppSectionHeader(title: 'More bays'),
              Wrap(
                spacing: _gap,
                runSpacing: _gap,
                children: [
                  for (final s in layout.unplaced)
                    bay(s, mirrored: false, w: bayW),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

// ── Bay ──────────────────────────────────────────────────────────────────────

class _Bay extends StatelessWidget {
  const _Bay({
    required this.slot,
    required this.state,
    required this.mirrored,
    required this.width,
    required this.height,
    required this.dimmed,
    required this.onTap,
  });

  final ParkingSlot slot;
  final BayState state;

  /// The right-hand column is the left one reflected: code on the outside edge,
  /// icon beside the lane.
  final bool mirrored;
  final double width;
  final double height;
  final bool dimmed;
  final VoidCallback onTap;

  bool get _isMotorcycle =>
      (slot.vehicleType ?? '').toLowerCase().contains('motor');

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _BayColors.of(t, state);

    final vehicleIcon = _isMotorcycle
        ? (state == BayState.free
              ? Icons.two_wheeler_outlined
              : Icons.two_wheeler_rounded)
        : (state == BayState.free
              ? Icons.directions_car_outlined
              : Icons.directions_car_rounded);

    final Widget trailing = switch (state) {
      // An icon, not a word: "Suggested" does not fit in a bay beside its code.
      // The legend and the sheet say what it means.
      BayState.suggested => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: t.brand.primary,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.near_me_rounded, size: 14, color: t.brand.onSolid),
      ),
      BayState.confirmed => Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: t.status.success.solid,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.check_rounded, size: 16, color: Colors.white),
      ),
      BayState.outOfService => Icon(
        Icons.block_rounded,
        size: AppSizes.iconMd,
        color: c.fg,
      ),
      BayState.noSignal => Icon(
        Icons.wifi_off_rounded,
        size: AppSizes.iconMd,
        color: c.fg,
      ),
      _ => Icon(vehicleIcon, size: AppSizes.iconMd, color: c.fg),
    };

    final code = Text(
      slot.slotCode,
      style: context.text.titleSmall?.copyWith(
        color: c.code,
        fontWeight: FontWeight.w800,
      ),
    );

    Widget bay = _FixedScale(
      child: Material(
        color: c.bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.smAll,
          side: BorderSide(color: c.border, width: c.borderWidth),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: AppRadius.smAll,
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: mirrored
                    ? [trailing, const Spacer(), code]
                    : [code, const Spacer(), trailing],
              ),
            ),
          ),
        ),
      ),
    );

    if (state == BayState.suggested) bay = _Pulse(child: bay);

    final kind = _isMotorcycle ? 'motorcycle bay' : 'car bay';

    return Semantics(
      button: true,
      label: '${slot.slotCode}, $kind, ${state.label.toLowerCase()}',
      excludeSemantics: true,
      onTap: onTap,
      child: Opacity(
        // Dimmed, not hidden: it is still a bay, just not the kind this driver
        // can use.
        opacity: dimmed ? 0.45 : 1,
        child: bay,
      ),
    );
  }
}

/// Holds the text inside the drawing to at most 1.3× the system size.
///
/// A bay and a gate bar are fixed-size shapes in a diagram; at the largest
/// accessibility text sizes their labels would burst out of them. A modest
/// ceiling keeps them readable and in place, and everything that is *not* a
/// diagram — the sheet a bay opens, the cards around the map — still scales
/// fully.
class _FixedScale extends StatelessWidget {
  const _FixedScale({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MediaQuery.withClampedTextScaling(
    minScaleFactor: 1,
    maxScaleFactor: 1.3,
    child: child,
  );
}

class _BayColors {
  const _BayColors(
    this.bg,
    this.border,
    this.fg, {
    this.borderWidth = 1.5,
    Color? code,
  }) : code = code ?? fg;

  final Color bg;
  final Color border;
  final Color fg;

  /// The bay's code. Separate from [fg] because the code is how a driver tells
  /// one bay from another, and it must stay readable on a bay whose *icon* is
  /// greyed out.
  final Color code;
  final double borderWidth;

  /// One function for the bay *and* the legend, so a key cannot describe a colour
  /// the map no longer uses.
  static _BayColors of(AppTokens t, BayState state) => switch (state) {
    // Mint rather than success green: a free bay is a place, not a verdict
    // on the driver.
    BayState.free => _BayColors(
      t.tertiary.subtle,
      t.tertiary.primary,
      t.tertiary.subtleText,
    ),
    BayState.taken => _BayColors(
      t.surface.muted,
      t.border.normal,
      t.text.secondary,
    ),
    BayState.outOfService || BayState.noSignal => _BayColors(
      t.surface.canvas,
      t.border.normal,
      t.text.disabled,
      code: t.text.secondary,
    ),
    BayState.suggested => _BayColors(
      t.tertiary.subtle,
      t.brand.primary,
      t.brand.subtleText,
      borderWidth: 2.5,
    ),
    BayState.confirmed => _BayColors(
      t.status.success.bg,
      t.status.success.solid,
      t.status.success.fg,
      borderWidth: 2.5,
    ),
  };
}

/// A slow ring around the suggested bay, so it can be found on a map of eighteen
/// look-alikes. Still, when the phone has been told to stop animating.
class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.of(context).disableAnimations) {
      _c.stop();
    } else if (!_c.isAnimating) {
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ring = context.tokens.brand.primary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => Transform.scale(
                scale: 1 + 0.12 * _c.value,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: AppRadius.smAll,
                    border: Border.all(
                      color: ring.withValues(alpha: 0.55 * (1 - _c.value)),
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }
}

// ── Lot furniture ────────────────────────────────────────────────────────────

class _GateRow extends StatelessWidget {
  const _GateRow({required this.gate, required this.entersDownward});

  final int gate;

  /// Gate 1's barrier is at the top and cars come in heading down; Gate 2's is at
  /// the bottom and they come in heading up.
  final bool entersDownward;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final wall = Container(
      height: 44,
      decoration: BoxDecoration(
        color: t.surface.muted,
        borderRadius: AppRadius.smAll,
      ),
    );

    return Row(
      children: [
        Expanded(child: wall),
        const SizedBox(width: 8),
        Semantics(
          label: 'Gate $gate',
          excludeSemantics: true,
          child: _FixedScale(
            child: Container(
              width: 124,
              height: 44,
              decoration: BoxDecoration(
                // The brand's deep indigo, as on the availability card above,
                // rather than near-black: the lot is part of the same app.
                color: t.brand.pressed,
                borderRadius: AppRadius.smAll,
              ),
              // Shrinks to fit rather than overflowing: the bar is a fixed shape.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      entersDownward
                          ? Icons.arrow_downward_rounded
                          : Icons.arrow_upward_rounded,
                      size: AppSizes.iconSm,
                      color: t.brand.onSolid,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'GATE $gate',
                      style: context.text.labelLarge?.copyWith(
                        color: t.brand.onSolid,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: wall),
      ],
    );
  }
}

class _Lane extends StatelessWidget {
  const _Lane({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return ExcludeSemantics(
      child: SizedBox(
        width: ParkingMap._lane,
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _DashPainter(t.border.normal)),
            ),
            Container(
              color: t.surface.card,
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: RotatedBox(
                quarterTurns: 3,
                child: Text(
                  'DRIVE LANE',
                  style: context.text.labelSmall?.copyWith(
                    letterSpacing: 2.4,
                    color: t.text.secondary,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                size: AppSizes.iconMd,
                color: t.text.secondary,
              ),
            ),
            Positioned(
              bottom: 0,
              child: Icon(
                Icons.keyboard_arrow_up_rounded,
                size: AppSizes.iconMd,
                color: t.text.secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashPainter extends CustomPainter {
  const _DashPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final x = size.width / 2;
    for (double y = 0; y < size.height; y += 12) {
      canvas.drawLine(Offset(x, y), Offset(x, y + 6), paint);
    }
  }

  @override
  bool shouldRepaint(_DashPainter old) => old.color != color;
}

// ── Legend ───────────────────────────────────────────────────────────────────

class _Legend extends StatelessWidget {
  const _Legend({required this.showSuggested, required this.showConfirmed});

  /// Only listed when the colour appears on the map. A key to something that is
  /// not there is noise.
  final bool showSuggested;
  final bool showConfirmed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.sm,
      children: [
        const _LegendItem(state: BayState.free),
        const _LegendItem(state: BayState.taken),
        const _LegendItem(state: BayState.outOfService),
        const _LegendItem(state: BayState.noSignal),
        if (showSuggested) const _LegendItem(state: BayState.suggested),
        if (showConfirmed) const _LegendItem(state: BayState.confirmed),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({required this.state});

  final BayState state;

  @override
  Widget build(BuildContext context) {
    final c = _BayColors.of(context.tokens, state);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A swatch of the real bay rather than a dot: the states differ by fill
        // and by border, and a dot can only show one.
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: c.bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: c.border, width: 1.5),
          ),
          // The two greyed states look alike as plain swatches, so they carry the
          // same glyph their bays do.
          child: switch (state) {
            BayState.outOfService => Icon(
              Icons.block_rounded,
              size: 12,
              color: context.tokens.text.secondary,
            ),
            BayState.noSignal => Icon(
              Icons.wifi_off_rounded,
              size: 12,
              color: context.tokens.text.secondary,
            ),
            _ => null,
          },
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(state.label, style: context.text.bodySmall)),
      ],
    );
  }
}

// ── What a tapped bay says ───────────────────────────────────────────────────

class _BaySheet extends StatelessWidget {
  const _BaySheet({
    required this.slot,
    required this.state,
    required this.wrongKindFor,
    this.refusedFor,
    this.onConfirm,
  });

  final ParkingSlot slot;
  final BayState state;

  /// Null when the map is only for looking.
  final Future<bool> Function(ParkingSlot slot)? onConfirm;

  /// Out-of-service bays cannot be parked in, so there is nothing to confirm.
  bool get _canConfirm =>
      onConfirm != null &&
      refusedFor == null &&
      state != BayState.outOfService &&
      state != BayState.confirmed;

  /// Set to `car` or `motorcycle` when the vehicle that came in is the other
  /// kind from this bay, so it cannot be confirmed here.
  final String? refusedFor;

  /// Set to `car` or `motorcycle` when this bay is for the other kind from the
  /// only kind of vehicle on the account.
  final String? wrongKindFor;

  bool get _isMotorcycle =>
      (slot.vehicleType ?? '').toLowerCase().contains('motor');

  StatusIntent get _intent => switch (state) {
    BayState.free => StatusIntent.success,
    BayState.taken || BayState.outOfService => StatusIntent.neutral,
    BayState.noSignal => StatusIntent.warning,
    BayState.suggested => StatusIntent.brand,
    BayState.confirmed => StatusIntent.success,
  };

  String get _message => switch (state) {
    // Asking where the driver parked: the sentence is about them, not the bay.
    BayState.free when _canConfirm =>
      'Parked here? Confirm it so the guards know which bay is yours.',
    BayState.taken when _canConfirm =>
      'The sensor says a vehicle is here. If it is yours, confirm it — the '
          'sensor is sometimes wrong.',
    BayState.noSignal when _canConfirm =>
      "This bay's sensor is not reporting. If you are parked here, confirm it.",
    BayState.free =>
      'Free right now. Looking at a bay does not hold it for you — entry '
          'is confirmed by your card at the gate.',
    BayState.taken => 'Someone is parked here.',
    BayState.outOfService => 'This bay is out of service.',
    BayState.noSignal =>
      "This bay's sensor is not reporting, so it is not counted as free.",
    BayState.suggested =>
      'Suggested for you. It is not held, so it may be taken before you '
          'arrive.',
    BayState.confirmed =>
      "You confirmed this bay, so you're responsible for it until you leave. "
          "It can't be changed here; if it's wrong, ask the parking office.",
  };

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = _BayColors.of(t, state);
    final kind = _isMotorcycle ? 'Motorcycle' : 'Car';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: c.bg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isMotorcycle
                        ? Icons.two_wheeler_rounded
                        : Icons.directions_car_rounded,
                    color: c.fg,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(slot.slotCode, style: context.text.headlineMedium),
                      Text(
                        'Gate ${slot.gate} · $kind bay',
                        style: context.text.bodySmall,
                      ),
                    ],
                  ),
                ),
                AppStatusBadge(
                  label: state.label,
                  intent: _intent,
                  showDot: true,
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            Text(_message, style: context.text.bodyMedium),
            if (_canConfirm) ...[
              const SizedBox(height: AppSpacing.md),
              _ConfirmBayButton(slot: slot, onConfirm: onConfirm!),
            ],
            if (refusedFor != null) ...[
              const SizedBox(height: AppSpacing.md),
              AppNotice(
                intent: StatusIntent.warning,
                message:
                    'This bay is for ${_isMotorcycle ? 'motorcycles' : 'cars'}, '
                    'and you came in on a $refusedFor. Pick a $refusedFor bay '
                    'to confirm.',
              ),
            ] else if (wrongKindFor != null && state == BayState.free) ...[
              const SizedBox(height: AppSpacing.sm),
              AppNotice(
                intent: StatusIntent.warning,
                message:
                    'This bay is for ${_isMotorcycle ? 'motorcycles' : 'cars'}. '
                    'Parking a $wrongKindFor here can be flagged.',
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Confirms the bay and closes the sheet when it worked. Stays open on failure,
/// where the caller has already shown why, so the driver can try again or pick
/// another bay.
///
/// Asks first: a confirm is final and makes the driver answerable for the
/// bay, and the bays are small enough on a phone to tap the wrong one.
class _ConfirmBayButton extends StatefulWidget {
  const _ConfirmBayButton({required this.slot, required this.onConfirm});

  final ParkingSlot slot;
  final Future<bool> Function(ParkingSlot slot) onConfirm;

  @override
  State<_ConfirmBayButton> createState() => _ConfirmBayButtonState();
}

class _ConfirmBayButtonState extends State<_ConfirmBayButton> {
  bool _busy = false;

  Future<void> _run() async {
    final code = widget.slot.slotCode;
    final sure = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Confirm bay $code?'),
        content: Text(
          "You'll be responsible for $code until you leave. This can't be "
          'changed after you confirm.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('Confirm $code'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() => _busy = true);
    var ok = false;
    try {
      ok = await widget.onConfirm(widget.slot);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    if (ok && mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        label: 'Confirm parking slot',
        icon: const Icon(Icons.check_circle_outline_rounded),
        isLoading: _busy,
        onPressed: _busy ? null : _run,
      ),
    );
  }
}
