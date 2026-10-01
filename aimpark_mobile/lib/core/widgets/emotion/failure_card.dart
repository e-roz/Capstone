import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../theme/emotion/emotion.dart';

/// The way out of a [FailureCard]. Deliberately just a label and a callback —
/// "retry", "view the alternative lot", "contact support" are all the same
/// shape of thing: one tappable action that gets the user unstuck.
@immutable
class FailureAlternative {
  const FailureAlternative({required this.label, required this.onTap});

  /// Names the action, e.g. "View Gym Lot", "Try again". Per brief §7, keep
  /// this name consistent with whatever screen it leads to.
  final String label;

  final VoidCallback onTap;
}

/// Brief §8, item 2 — the component that enforces the system's one
/// non-negotiable rule (brief §1): **a red state must always carry an
/// alternative.** The app never presents a dead end.
///
/// [alternative] is `required` and [FailureAlternative]'s own two fields are
/// non-nullable with no defaults, so there is no construction path that
/// produces a `FailureCard` with nothing to tap — that is enforced by the
/// compiler, not by a runtime check or a lint. Do not add a default, a
/// nullable override, or an "empty" [FailureAlternative] to make some call
/// site more convenient; that would silently reopen the dead end this
/// component exists to close.
///
/// Carries no red or orange accent. The palette's closest "failure" hue,
/// [EmotionAvailTokens.full], means lot-full specifically (brief §3) — most
/// of what lands on this card (a misread card, a failed payment, a dropped
/// connection) has nothing to do with lot availability, so borrowing that
/// colour here would blur exactly the status meaning the hard rule protects.
/// This card is deliberately unalarming: [EmotionSurfaceTokens.raised], plain
/// text, and one [EmotionSignalTokens.blue] button — the only colour that
/// means "tap this" anywhere in the system. Per brief §7, the longest and
/// warmest copy in the app belongs here; that is where trust gets built, not
/// in a red icon.
///
/// Fires [EmotionHapticTokens.error] once, on first build — the weakest
/// pattern in the system (brief §6). Never escalate it, even though the
/// event that triggered this card may feel urgent: a failure the system
/// caused should never be felt as a punishment.
class FailureCard extends StatefulWidget {
  const FailureCard({
    super.key,
    required this.message,
    required this.alternative,
    this.detail,
  });

  /// The fact, read first — e.g. "Gate A is full right now." Never phrase
  /// this as the user's fault (brief §2).
  final String message;

  /// The warmer second sentence, read second — e.g. "Gym Lot has 6 open —
  /// about a 2-minute walk." Optional: some failures (a dropped connection)
  /// need no more explanation than [message] already gives.
  final String? detail;

  /// The way out. See class doc — this is what makes a dead end a compile
  /// error instead of a runtime possibility.
  final FailureAlternative alternative;

  @override
  State<FailureCard> createState() => _FailureCardState();
}

class _FailureCardState extends State<FailureCard> {
  @override
  void initState() {
    super.initState();
    // No themed state involved, so — like the gate view's success haptic —
    // this can fire immediately rather than waiting on the first frame.
    EmotionTokens.instance.haptic.error();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.emotion;

    return Container(
      decoration: BoxDecoration(
        color: e.surface.raised,
        borderRadius: AppRadius.lgAll,
      ),
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message,
            style: e.typography.sectionHeading.copyWith(color: e.paint.white),
          ),
          if (widget.detail != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              widget.detail!,
              style: e.typography.body.copyWith(color: e.paint.muted),
            ),
          ],
          const SizedBox(height: AppSpacing.md),
          _AlternativeButton(alternative: widget.alternative, e: e),
        ],
      ),
    );
  }
}

class _AlternativeButton extends StatelessWidget {
  const _AlternativeButton({required this.alternative, required this.e});

  final FailureAlternative alternative;
  final EmotionTokens e;

  @override
  Widget build(BuildContext context) {
    // AppSizes.controlHeight is 48dp — brief §9's tap-target floor, gloves or
    // a hand braced against the wheel included.
    return SizedBox(
      width: double.infinity,
      height: AppSizes.controlHeight,
      child: Material(
        color: e.signal.blue,
        borderRadius: AppRadius.mdAll,
        child: InkWell(
          borderRadius: AppRadius.mdAll,
          onTap: alternative.onTap,
          child: Center(
            child: Text(
              alternative.label,
              style: e.typography.body.copyWith(
                color: e.paint.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
