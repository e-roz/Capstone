import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// One wedge of a 24-hour rose chart.
@immutable
class AppPolarDatum {
  const AppPolarDatum({required this.label, required this.value});

  /// The hour, "0"–"23".
  final String label;
  final double value;
}

/// A 24-hour "rose" — value plotted as radius around a clock face, the
/// reference dashboard's compass-style wind-direction plot repurposed for
/// data that is genuinely circular: the hour of day. Traffic bunched at 8am
/// and 5pm reads as two lobes at a glance, which a bar chart with 24 columns
/// cannot show as directly.
class AppPolarBarChart extends StatelessWidget {
  const AppPolarBarChart({
    super.key,
    required this.data,
    this.size = 190,
    this.lowColor,
    this.highColor,
  });

  /// 24 entries, hour 0 to 23, in order.
  final List<AppPolarDatum> data;
  final double size;

  /// Wedges are coloured by their own value, quiet hours toward [lowColor]
  /// and busy ones toward [highColor] — a small heat-map rather than one flat
  /// hue, so the busiest slice reads as "hot" at a glance.
  final Color? lowColor;
  final Color? highColor;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final low = lowColor ?? t.chart.series(4);
    final high = highColor ?? t.chart.series(3);
    final maxValue = data.isEmpty
        ? 1.0
        : data.map((d) => d.value).fold(0.0, math.max).clamp(1.0, double.infinity);

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        builder: (context, t2, _) => CustomPaint(
          size: Size(size, size),
          painter: _PolarPainter(
            data: data,
            maxValue: maxValue,
            progress: t2,
            lowColor: low,
            highColor: high,
            grid: t.chart.grid,
            label: t.text.tertiary,
            textDirection: Directionality.of(context),
          ),
        ),
      ),
    );
  }
}

class _PolarPainter extends CustomPainter {
  const _PolarPainter({
    required this.data,
    required this.maxValue,
    required this.progress,
    required this.lowColor,
    required this.highColor,
    required this.grid,
    required this.label,
    required this.textDirection,
  });

  final List<AppPolarDatum> data;
  final double maxValue;
  final double progress;
  final Color lowColor;
  final Color highColor;
  final Color grid;
  final Color label;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final maxRadius = size.shortestSide / 2 - 18;

    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;

    for (final f in [0.34, 0.67, 1.0]) {
      canvas.drawCircle(centre, maxRadius * f, gridPaint);
    }
    for (final hour in [0, 6, 12, 18]) {
      final angle = _angleFor(hour);
      final p = centre + Offset(math.cos(angle), math.sin(angle)) * maxRadius;
      canvas.drawLine(centre, p, gridPaint);
      _label(canvas, hour == 0 ? '12am' : hour == 12 ? '12pm' : '$hour:00',
          centre + Offset(math.cos(angle), math.sin(angle)) * (maxRadius + 10));
    }

    if (data.isEmpty) return;

    final wedgeAngle = (2 * math.pi / data.length) * 0.72;

    for (final d in data) {
      final hour = int.tryParse(d.label) ?? 0;
      final angle = _angleFor(hour);
      final ratio = d.value / maxValue;
      // A small coloured floor rather than nothing: an hour with zero
      // entries is still part of the clock face, and a chart with every
      // wedge invisible reads as broken rather than as "quiet".
      final r = math.max(maxRadius * 0.08, maxRadius * ratio) * progress;
      final rect = Rect.fromCircle(center: centre, radius: r);
      final fill = Paint()
        ..color = Color.lerp(lowColor, highColor, ratio.clamp(0.0, 1.0))!
            .withValues(alpha: ratio <= 0 ? 0.35 : 0.9);
      canvas.drawArc(rect, angle - wedgeAngle / 2, wedgeAngle, true, fill);
    }
  }

  double _angleFor(int hour) => (hour / 24) * 2 * math.pi - math.pi / 2;

  void _label(Canvas canvas, String text, Offset at) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: label),
      ),
      textDirection: textDirection,
    )..layout();
    painter.paint(canvas, at - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_PolarPainter old) =>
      old.progress != progress ||
      old.data != data ||
      old.lowColor != lowColor ||
      old.highColor != highColor;
}
