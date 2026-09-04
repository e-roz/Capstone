import 'package:flutter/material.dart';

import '../../theme/app_dimensions.dart';
import '../../theme/emotion/emotion.dart';

/// The peak emotional moment of the app (brief §8, item 1): a full-bleed
/// confirmation shown the instant the gate opens. It is the only place
/// [EmotionMotionTokens.gate] — the app's single overshoot animation — is
/// allowed to appear, paired with exactly one [EmotionHapticTokens.success]
/// impact and nothing else. No confetti, no sound, no second beat; reusing
/// this motion or haptic anywhere else destroys the one moment it exists to
/// mark.
///
/// Deliberately colourless where it would be easiest to reach for green: the
/// palette's only "success"-shaped hue is [EmotionAvailTokens.open], and that
/// is reserved for lot availability (brief §3, "Hard rule"). Reusing it here
/// would teach a driver that green sometimes means "gate open" instead of
/// "plenty of space" — exactly the ambiguity the rule exists to prevent. The
/// feeling of success is carried by the overshoot motion, the haptic and the
/// copy alone, on plain [EmotionPaintTokens.white].
///
/// The two copy rows in brief §7 ("Gate open" / "Gate open, returning user")
/// are not alternatives — they compose. The fact line always shows; the
/// warmer, personalised line appears underneath it only when
/// [returningUserName] is given, fact first and warmth second per the voice
/// rules in brief §2.
class GateFeedbackView extends StatefulWidget {
  const GateFeedbackView({
    super.key,
    required this.slotId,
    this.returningUserName,
    this.onDismiss,
  });

  /// e.g. "B-14".
  final String slotId;

  /// First name only, e.g. "Jean". Omit to show the fact-only copy.
  final String? returningUserName;

  /// Fires when the user taps anywhere on the screen. There is no visible
  /// button here — this is arm's-length, one-handed, eyes on the gate — so
  /// the full-bleed surface itself is the only dismiss target. Leave null if
  /// the caller dismisses on a timer instead.
  final VoidCallback? onDismiss;

  @override
  State<GateFeedbackView> createState() => _GateFeedbackViewState();
}

class _GateFeedbackViewState extends State<GateFeedbackView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _progress;
  bool _reduceMotion = false;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    // Haptics carry no themed state, so this can fire immediately instead of
    // waiting on the first frame — the point is that it lands the instant the
    // gate opens, not the instant the animation finishes.
    EmotionTokens.instance.haptic.success();
    _controller = AnimationController(vsync: this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;

    _reduceMotion = MediaQuery.of(context).disableAnimations;
    final motion = EmotionTokens.instance.motion;
    // Reduced motion still has to show the state change (brief §5) — it just
    // loses the overshoot and becomes a plain cross-fade at the standard
    // duration instead of the signature gate one.
    final spec = _reduceMotion ? motion.standard : motion.gate;

    _controller.duration = spec.duration;
    _progress = CurvedAnimation(parent: _controller, curve: spec.curve);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = context.emotion;

    return Material(
      color: e.surface.asphalt,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onDismiss,
        child: SizedBox.expand(
          child: SafeArea(
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, child) {
                final opacity = _progress.value.clamp(0.0, 1.0);
                // Overshoot only ever drives the scale, never the opacity —
                // a value above 1.0 mid-bounce would fail Opacity's assert.
                // Reduced motion drops the scale entirely rather than just
                // swapping its curve, so the fallback reads as a plain fade,
                // never as a shrunken bounce.
                final scale = _reduceMotion ? 1.0 : _progress.value;

                return Opacity(
                  opacity: opacity,
                  child: Transform.scale(scale: scale, child: child),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CheckBadge(color: e.paint.white),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      "You're in.",
                      textAlign: TextAlign.center,
                      style: e.typography.screenTitle.copyWith(
                        color: e.paint.white,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text.rich(
                      TextSpan(
                        style: e.typography.body.copyWith(
                          color: e.paint.muted,
                        ),
                        children: [
                          const TextSpan(text: 'Slot '),
                          TextSpan(
                            text: widget.slotId,
                            style: e.typography.slotId.copyWith(
                              color: e.paint.white,
                            ),
                          ),
                          const TextSpan(text: ' is open.'),
                        ],
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (widget.returningUserName != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Welcome back, ${widget.returningUserName}.',
                        textAlign: TextAlign.center,
                        style: e.typography.caption.copyWith(
                          color: e.paint.muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain ring-and-check — no colour, no icon-font swap, nothing that reads
/// as a mascot. The overshoot on [GateFeedbackView]'s scale animation is what
/// makes this feel alive, not the shape itself.
class _CheckBadge extends StatelessWidget {
  const _CheckBadge({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      height: 88,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 3),
      ),
      child: Icon(Icons.check_rounded, color: color, size: 44),
    );
  }
}
