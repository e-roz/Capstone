import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A speedometer-style arc gauge — open at the bottom rather than a full
/// ring, with the value's domain labelled at each end. This is the shape the
/// reference dashboard uses for "Real-time power": a live reading against a
/// known range, not a share of a whole (that is [AppProgressRing]'s job).
class AppArcGauge extends StatelessWidget {
  const AppArcGauge({
    super.key,
    required this.value,
    this.size = 180,
    this.strokeWidth = 14,
    this.color,
    this.endColor,
    this.minLabel,
    this.maxLabel,
    this.center,
  });

  /// 0–1 already normalised against whatever domain [minLabel]/[maxLabel]
  /// describe.
  final double value;

  final double size;
  final double strokeWidth;
  final Color? color;

  /// When set, the value arc sweeps from [color] to this colour rather than
  /// painting flat — the gradient treatment the reference dashboard gives
  /// every live reading, not just a single accent hue.
  final Color? endColor;

  /// Printed under the gauge's two open ends — the domain the reading sits
  /// in, e.g. "0" and "1.2k".
  final String? minLabel;
  final String? maxLabel;

  final Widget? center;

  static const _start = math.pi * 0.75; // 135°, bottom-left
  static const _sweep = math.pi * 1.5; // 270°, open at the bottom

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final resolved = color ?? t.brand.primary;
    final resolvedEnd = endColor ?? Color.lerp(resolved, Colors.white, 0.35)!;
    // A neutral-grey track reads as "empty" rather than "this gauge's own
    // colour, resting" — tinting it toward the gauge's hue keeps the card
    // looking like itself even when the live value is zero.
    final track = Color.lerp(resolved, t.surface.muted, 0.82)!;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        builder: (context, animated, _) => Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size, size),
              painter: _ArcGaugePainter(
                value: animated,
                colorStart: resolvedEnd,
                colorEnd: resolved,
                track: track,
                strokeWidth: strokeWidth,
              ),
            ),
            if (center != null) Padding(
              padding: EdgeInsets.only(top: size * 0.08),
              child: center,
            ),
            if (minLabel != null)
              Positioned(
                bottom: size * 0.06,
                left: size * 0.10,
                child: Text(minLabel!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: t.text.tertiary)),
              ),
            if (maxLabel != null)
              Positioned(
                bottom: size * 0.06,
                right: size * 0.10,
                child: Text(maxLabel!,
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: t.text.tertiary)),
              ),
          ],
        ),
      ),
    );
  }
}

class _ArcGaugePainter extends CustomPainter {
  const _ArcGaugePainter({
    required this.value,
    required this.colorStart,
    required this.colorEnd,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color colorStart;
  final Color colorEnd;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final arcRect = Rect.fromCircle(center: centre, radius: radius);

    final track_ = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = track;

    canvas.drawArc(arcRect, AppArcGauge._start, AppArcGauge._sweep, false, track_);

    if (value <= 0) return;
    final gradientPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: AppArcGauge._start,
        endAngle: AppArcGauge._start + AppArcGauge._sweep,
        colors: [colorStart, colorEnd],
        transform: GradientRotation(0),
      ).createShader(arcRect);

    canvas.drawArc(
      arcRect,
      AppArcGauge._start,
      AppArcGauge._sweep * value,
      false,
      gradientPaint,
    );
  }

  @override
  bool shouldRepaint(_ArcGaugePainter old) =>
      old.value != value ||
      old.colorStart != colorStart ||
      old.colorEnd != colorEnd ||
      old.track != track;
}
