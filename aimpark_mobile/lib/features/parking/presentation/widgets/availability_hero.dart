import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/parking_slot.dart';
import 'availability_freshness.dart';
import 'availability_level.dart';

/// The lot's availability as one brand-coloured surface: is there room, and for
/// what. Shown on Home and at the top of the Parking tab, so the two always say
/// the same thing in the same way.
///
/// Answers three things in this order — how full the lot is (the word and the
/// colour), how many bays are free (the number), and whether any of them is the
/// right kind for the vehicles on this account (the two type chips and, when
/// there is a mismatch, a sentence saying so in plain words). A lot with twelve
/// free bays, all of them motorcycle bays, is full for a car; the gate admits by
/// vehicle type, so this card must not say "12 free" and leave it there.
///
/// The surface changes with the state, not only the label: bright with a mint
/// glow when there is room, an amber glow when it is filling, flat and still when
/// it is full. A calm green wash behind the word "Full" told the wrong story.
///
/// On Home the whole card opens the Parking tab and the button inside goes
/// there too; on the Parking tab itself both are left off ([onOpenParking] and
/// [onSelectSlot] null). The button is only there when there is a bay to pick.
/// There is no refresh button: the count updates itself every few seconds and the screen
/// pulls down to refresh. A "Refresh" link appears only when the count has gone
/// stale, which is when someone has a reason to ask.
class AvailabilityHero extends StatefulWidget {
  const AvailabilityHero({
    super.key,
    required this.availability,
    required this.userHasCar,
    required this.userHasMotorcycle,
    this.onOpenParking,
    this.onSelectSlot,
    required this.onRefresh,
  });

  final ParkingAvailability availability;

  /// Which kinds of vehicle are registered to this account. Neither, for an
  /// account with no vehicle yet — then no chip is emphasised and no mismatch is
  /// reported.
  final bool userHasCar;
  final bool userHasMotorcycle;

  /// Makes the whole card tappable. Null leaves it a plain display.
  final VoidCallback? onOpenParking;

  /// Shows the "Find a slot" button. Null leaves it off.
  final VoidCallback? onSelectSlot;
  final VoidCallback onRefresh;

  @override
  State<AvailabilityHero> createState() => _AvailabilityHeroState();
}

class _AvailabilityHeroState extends State<AvailabilityHero> {
  bool _isPressed = false;

  /// Set when every kind of vehicle this account has is out of bays while other
  /// kinds are not — the case where the total is true and no use.
  ({String kind, String others, int othersFree})? _mismatch() {
    final a = widget.availability;
    if (a.availableSlots <= 0 || a.isPaused) return null;

    final carsOut = widget.userHasCar && a.freeCars == 0;
    final motosOut = widget.userHasMotorcycle && a.freeMotorcycles == 0;

    if (widget.userHasCar &&
        !widget.userHasMotorcycle &&
        carsOut &&
        a.freeMotorcycles > 0) {
      return (kind: 'car', others: 'motorcycle', othersFree: a.freeMotorcycles);
    }
    if (widget.userHasMotorcycle &&
        !widget.userHasCar &&
        motosOut &&
        a.freeCars > 0) {
      return (kind: 'motorcycle', others: 'car', othersFree: a.freeCars);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final a = widget.availability;
    final level = AvailabilityLevel.of(a);
    final mismatch = _mismatch();

    // What this driver should see: a lot with bays, but none for their vehicle,
    // is full to them.
    final effective = mismatch != null ? AvailabilityLevel.full : level;
    final paused = effective == AvailabilityLevel.paused;
    final canPick =
        widget.onSelectSlot != null &&
        effective != AvailabilityLevel.full &&
        !paused;
    final tappable = widget.onOpenParking != null;

    final onSolid = t.brand.onSolid;
    final muted = onSolid.withValues(alpha: 0.78);

    final colors = switch (effective) {
      AvailabilityLevel.open => [
        t.brand.primary,
        t.brand.pressed,
        t.tertiary.pressed,
      ],
      AvailabilityLevel.filling => [
        t.brand.primary,
        t.brand.pressed,
        t.status.warning.fg,
      ],
      // Flat and still for both: neither is good news, and neither should glow.
      AvailabilityLevel.full ||
      AvailabilityLevel.paused => [t.brand.pressed, t.brand.pressed],
    };

    final chipLabel = mismatch != null
        ? 'Full for ${mismatch.kind == 'car' ? 'cars' : 'motorcycles'}'
        : effective.label;

    final headline = paused
        ? '—'
        : effective == AvailabilityLevel.full && mismatch == null
        ? 'Full'
        : '${a.availableSlots}';
    final subline = switch ((effective, mismatch)) {
      (AvailabilityLevel.paused, _) =>
        'Live parking is paused right now. The sensors are not reporting.',
      (AvailabilityLevel.full, null) => 'No bays free right now',
      (_, final m?) => 'of ${a.totalSlots} bays free, none for a ${m.kind}',
      _ => 'of ${a.totalSlots} bays free',
    };

    // The age of the count is when the lot last *reported*, by the server's
    // clock. The phone's own fetch time only says when it last asked, which is
    // how a lot with the power off came to read "Updated just now".
    final freshness = AvailabilityFreshness.of(a.asOf);
    final freshnessLabel = paused
        ? (a.lastHeardAt == null
            ? 'No live reading from the lot'
            : 'Last update ${Formatters.relativeTime(a.lastHeardAt!)}')
        : freshness.label(a.asOf);
    final freshnessDot = paused
        ? t.status.warning.border
        : t.status.of(freshness.intent).border;
    final isStale = freshness == AvailabilityFreshness.stale;

    final summary = [
      'Parking availability',
      chipLabel,
      if (paused)
        'The live feed is paused, so the count is not available'
      else ...[
        '${a.availableSlots} of ${a.totalSlots} bays free',
        '${a.freeCars} for cars, ${a.freeMotorcycles} for motorcycles',
      ],
      if (mismatch != null)
        'No ${mismatch.kind} bays free. ${mismatch.othersFree} '
            '${mismatch.others} bays open.',
      freshnessLabel,
    ].join('. ');

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: !tappable
          ? null
          : () {
              HapticFeedback.selectionClick();
              widget.onOpenParking!();
            },
      child: AnimatedScale(
        scale: _isPressed ? 0.985 : 1.0,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : AppMotion.press,
        curve: AppMotion.standard,
        child: Semantics(
          container: true,
          button: tappable,
          label: summary,
          onTap: widget.onOpenParking,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.md + 4),
            decoration: BoxDecoration(
              borderRadius: AppRadius.lgAll,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: colors,
                stops: colors.length == 3 ? const [0.0, 0.62, 1.0] : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Everything above the button is read once, as the summary
                // above; the button keeps its own stop.
                ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _StateChip(label: chipLabel, onSolid: onSolid),
                      const SizedBox(height: AppSpacing.sm + 4),
                      if (paused)
                        Text(
                          'The lot is not reporting right now. The count and the '
                          'bay colours will come back when it reconnects.',
                          style: context.text.bodyMedium?.copyWith(
                            color: onSolid,
                          ),
                        )
                      else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              headline,
                              style: AppTypography.tabular(
                                context.text.displayLarge!,
                              ).copyWith(color: onSolid),
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Flexible(
                              child: Text(
                                subline,
                                style: context.text.bodyMedium?.copyWith(
                                  color: muted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppSpacing.md),
                        // Wraps rather than overflowing when the system text is large.
                        Wrap(
                          spacing: AppSpacing.sm,
                          runSpacing: AppSpacing.sm,
                          children: [
                            _TypeChip(
                              icon: Icons.directions_car_rounded,
                              label: 'Cars',
                              count: paused ? '–' : '${a.freeCars}',
                              mine: widget.userHasCar,
                            ),
                            _TypeChip(
                              icon: Icons.two_wheeler_rounded,
                              label: 'Motorcycles',
                              count: paused ? '–' : '${a.freeMotorcycles}',
                              mine: widget.userHasMotorcycle,
                            ),
                          ],
                        ),
                        if (mismatch != null) ...[
                          const SizedBox(height: AppSpacing.sm + 4),
                          Text(
                            'No ${mismatch.kind} bays free right now. '
                            '${mismatch.othersFree} ${mismatch.others} '
                            '${mismatch.othersFree == 1 ? 'bay is' : 'bays are'} '
                            'open.',
                            style: context.text.bodySmall?.copyWith(
                              color: onSolid,
                            ),
                          ),
                        ],
                      ],
                      const SizedBox(height: AppSpacing.sm + 4),
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              // The light end of the tone: the solid one is too
                              // dark to be seen against the indigo.
                              color: freshnessDot,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              freshnessLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(
                                color: muted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (isStale)
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Transform.translate(
                      // Pulled back by the link's own side padding so its text
                      // lines up with the lines above.
                      offset: const Offset(-AppSpacing.sm, 0),
                      child: AppTextLink(
                        label: 'Refresh',
                        onTap: widget.onRefresh,
                        color: onSolid,
                        semanticLabel: 'Refresh availability',
                      ),
                    ),
                  ),
                if (canPick) ...[
                  const SizedBox(height: AppSpacing.sm),
                  AppButton(
                    label: 'Find a slot',
                    style: AppButtonStyle.inverse,
                    onPressed: widget.onSelectSlot,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A translucent pill on the wash carrying the lot's state in words.
class _StateChip extends StatelessWidget {
  const _StateChip({required this.label, required this.onSolid});

  final String label;
  final Color onSolid;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: onSolid.withValues(alpha: 0.16),
        borderRadius: AppRadius.fullAll,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: onSolid, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            label.toUpperCase(),
            style: context.text.labelMedium?.copyWith(color: onSolid),
          ),
        ],
      ),
    );
  }
}

/// How many bays are free for one kind of vehicle. Solid white when it is a kind
/// this account owns, so the figure that matters is the one that stands out.
class _TypeChip extends StatelessWidget {
  const _TypeChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.mine,
  });

  final IconData icon;
  final String label;
  final String count;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fill = mine
        ? t.surface.card
        : t.brand.onSolid.withValues(alpha: 0.16);
    final fg = mine ? t.brand.subtleText : t.brand.onSolid;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: fill, borderRadius: AppRadius.fullAll),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: AppSizes.iconMd, color: fg),
          const SizedBox(width: 6),
          Text('$label ', style: context.text.labelLarge?.copyWith(color: fg)),
          Text(
            count,
            style: AppTypography.tabular(
              context.text.labelLarge!.copyWith(
                color: fg,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
