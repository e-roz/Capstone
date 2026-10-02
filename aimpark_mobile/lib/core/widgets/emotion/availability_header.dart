import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../theme/emotion/emotion.dart';
import 'availability_confidence.dart';

/// Brief §8, item 3 — the hero slot count, coloured by [AvailabilityConfidence]
/// (brief §3). Unlike the gate feedback view's checkmark or the failure
/// card, this component's whole reason to exist *is* an availability status,
/// so — unlike those two — it is exactly the right place to reach for
/// [EmotionTokens.avail]: that is what the colour is for here.
///
/// Presentational only. [statusLine] is composed by the caller, not this
/// widget — pluralising "slot"/"slots" and deciding the count thresholds for
/// each [AvailabilityConfidence] are domain decisions that don't belong
/// inside a display widget, mirroring how this codebase already keeps a
/// domain's status mapping (`StatusIntents`) out of its status badge widget.
///
/// Brief §9's accessibility floor ("pair every availability colour with a
/// label or count") is met twice over: the count is the hero number itself,
/// and [statusLine] is the label — colour is never the only signal.
///
/// Fires [EmotionHapticTokens.warning] itself, but only on the transition
/// into [AvailabilityConfidence.filling] — never on first build, and never
/// on a rebuild while already filling. A screen that opens already showing a
/// filling lot (the user opened the app mid-afternoon) should not buzz on
/// load; only the moment it *becomes* filling should.
class AvailabilityHeader extends StatefulWidget {
  const AvailabilityHeader({
    super.key,
    required this.gateName,
    required this.slotsOpen,
    required this.confidence,
    required this.statusLine,
  });

  /// e.g. "Gate A".
  final String gateName;

  /// The hero number.
  final int slotsOpen;

  final AvailabilityConfidence confidence;

  /// The caller-composed sentence, e.g. "Gate A is filling up — 4 slots
  /// left." (brief §7's exact "Lot filling" copy). Read second, in
  /// [EmotionPaintTokens.muted] — the count and its colour carry the
  /// headline, this carries the words that make it unambiguous.
  final String statusLine;

  @override
  State<AvailabilityHeader> createState() => _AvailabilityHeaderState();
}

class _AvailabilityHeaderState extends State<AvailabilityHeader> {
  @override
  void didUpdateWidget(covariant AvailabilityHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    final justStartedFilling =
        widget.confidence == AvailabilityConfidence.filling &&
            oldWidget.confidence != AvailabilityConfidence.filling;
    if (justStartedFilling) {
      EmotionTokens.instance.haptic.warning();
    }
  }

  @override
  Widget build(BuildContext context) {
    final e = context.emotion;
    final color = widget.confidence.colorOf(e);

    return Semantics(
      label: '${widget.gateName}. ${widget.statusLine}',
      container: true,
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.gateName,
              style: e.typography.sectionHeading.copyWith(
                color: e.paint.white,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              '${widget.slotsOpen}',
              style: e.typography.slotCount.copyWith(color: color),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.statusLine,
              style: e.typography.body.copyWith(color: e.paint.muted),
            ),
          ],
        ),
      ),
    );
  }
}
