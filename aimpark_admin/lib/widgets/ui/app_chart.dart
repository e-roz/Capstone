import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// One labelled value in a chart.
@immutable
class AppChartDatum {
  const AppChartDatum({
    required this.label,
    required this.value,
    this.tooltip,
  });

  /// Shown on the category axis.
  final String label;

  final double value;

  /// Shown on hover. Falls back to "label: value".
  final String? tooltip;
}

/// Shared axis, grid and tooltip treatment.
///
/// Charts are the one place a design system usually leaks, because plotting
/// libraries ship their own opinions about grey. Everything visible below reads
/// from tokens — series colour from [AppChartTokens.series], gridlines from
/// `t.chart.grid`, tooltips from the inverse surface — so the charts follow
/// dark mode and any future palette change without being touched.
class _ChartChrome {
  const _ChartChrome(this.context);

  final BuildContext context;

  AppTokens get t => context.tokens;
  TextTheme get text => Theme.of(context).textTheme;

  FlGridData grid(double interval) => FlGridData(
        show: true,
        drawVerticalLine: false,
        horizontalInterval: interval <= 0 ? 1 : interval,
        getDrawingHorizontalLine: (_) =>
            FlLine(color: t.chart.grid, strokeWidth: 1),
      );

  /// The value axis. Labels are deliberately sparse — five gridlines is enough
  /// to read a magnitude, and more turns the plot into graph paper.
  AxisTitles valueAxis(double interval, String Function(double) format) =>
      AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 48,
          interval: interval <= 0 ? 1 : interval,
          getTitlesWidget: (value, meta) {
            if (value <= 0 || value >= meta.max) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              child: Text(
                format(value),
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            );
          },
        ),
      );

  AxisTitles categoryAxis(List<AppChartDatum> data, int every) => AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 28,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final i = value.round();
            if (i < 0 || i >= data.length) return const SizedBox.shrink();
            // With thirty categories every label would overlap its neighbour,
            // so only every nth is drawn.
            if (every > 1 && i % every != 0) return const SizedBox.shrink();
            return SideTitleWidget(
              meta: meta,
              child: Text(
                data[i].label,
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            );
          },
        ),
      );

  static const hidden =
      AxisTitles(sideTitles: SideTitles(showTitles: false));
}

/// Rounds a maximum up to something a human would pick for an axis, so the top
/// gridline reads "400" rather than "387.4".
double _niceMax(double raw) {
  if (raw <= 0) return 4;
  final magnitude = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
  final normalised = raw / magnitude;
  final step = switch (normalised) {
    <= 1 => 1.0,
    <= 2 => 2.0,
    <= 4 => 4.0,
    <= 5 => 5.0,
    _ => 10.0,
  };
  return step * magnitude;
}

int _labelEvery(int count) => count <= 10
    ? 1
    : count <= 20
        ? 2
        : (count / 10).ceil();

/// A vertical bar chart.
///
/// Replaces the hand-rolled `_SimpleBarChart` on Reports, which drew plain
/// `Container`s with no axis, no gridlines and no tooltips — the single most
/// "unfinished" thing on any screen in the panel.
class AppBarChart extends StatelessWidget {
  const AppBarChart({
    super.key,
    required this.data,
    this.seriesIndex = 0,
    this.valueLabel,
    this.height = 220,
  });

  final List<AppChartDatum> data;

  /// Index into the categorical palette, so two charts on one screen can be
  /// told apart without either picking a colour by hand.
  final int seriesIndex;

  /// Formats axis and tooltip values — money, counts, percentages.
  final String Function(double value)? valueLabel;

  final double height;

  @override
  Widget build(BuildContext context) {
    final chrome = _ChartChrome(context);
    final t = chrome.t;
    final format = valueLabel ?? (v) => v.round().toString();

    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data for this period',
            style: chrome.text.bodySmall?.copyWith(color: t.text.tertiary),
          ),
        ),
      );
    }

    final color = t.chart.series(seriesIndex);
    final maxY = _niceMax(data.map((d) => d.value).reduce(math.max));
    final interval = maxY / 4;

    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: chrome.grid(interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: chrome.valueAxis(interval, format),
            bottomTitles: chrome.categoryAxis(data, _labelEvery(data.length)),
            topTitles: _ChartChrome.hidden,
            rightTitles: _ChartChrome.hidden,
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.surface.inverse,
              tooltipBorderRadius: AppRadii.smAll,
              getTooltipItem: (group, groupIndex, rod, rodIndex) =>
                  BarTooltipItem(
                data[groupIndex].tooltip ??
                    '${data[groupIndex].label} · ${format(rod.toY)}',
                chrome.text.bodySmall!.copyWith(color: t.text.inverse),
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < data.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: data[i].value,
                    color: color,
                    width: data.length > 20 ? 8 : 16,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(3),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: t.surface.muted,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

/// A filled line chart, for anything that accumulates over time.
///
/// A trend gets an area rather than bars because the shape of the line is the
/// message; bars invite comparing individual days that nobody compares.
class AppAreaChart extends StatelessWidget {
  const AppAreaChart({
    super.key,
    required this.data,
    this.seriesIndex = 0,
    this.valueLabel,
    this.height = 220,
  });

  final List<AppChartDatum> data;
  final int seriesIndex;
  final String Function(double value)? valueLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final chrome = _ChartChrome(context);
    final t = chrome.t;
    final format = valueLabel ?? (v) => v.round().toString();

    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No data for this period',
            style: chrome.text.bodySmall?.copyWith(color: t.text.tertiary),
          ),
        ),
      );
    }

    final color = t.chart.series(seriesIndex);
    final maxY = _niceMax(data.map((d) => d.value).reduce(math.max));
    final interval = maxY / 4;

    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          maxY: maxY,
          minY: 0,
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          gridData: chrome.grid(interval),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: chrome.valueAxis(interval, format),
            bottomTitles: chrome.categoryAxis(data, _labelEvery(data.length)),
            topTitles: _ChartChrome.hidden,
            rightTitles: _ChartChrome.hidden,
          ),
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => t.surface.inverse,
              tooltipBorderRadius: AppRadii.smAll,
              getTooltipItems: (spots) => [
                for (final spot in spots)
                  LineTooltipItem(
                    data[spot.x.round()].tooltip ??
                        '${data[spot.x.round()].label} · ${format(spot.y)}',
                    chrome.text.bodySmall!.copyWith(color: t.text.inverse),
                  ),
              ],
            ),
            getTouchedSpotIndicator: (barData, indexes) => [
              for (final _ in indexes)
                TouchedSpotIndicatorData(
                  FlLine(color: color, strokeWidth: 1),
                  FlDotData(
                    getDotPainter: (spot, percent, bar, index) =>
                        FlDotCirclePainter(
                      radius: 4,
                      color: color,
                      strokeWidth: 2,
                      strokeColor: t.surface.card,
                    ),
                  ),
                ),
            ],
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++)
                  FlSpot(i.toDouble(), data[i].value),
              ],
              isCurved: true,
              curveSmoothness: 0.25,
              preventCurveOverShooting: true,
              color: color,
              barWidth: 2.5,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: 0.28),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A ring showing one proportion, with whatever matters most in the middle.
///
/// This is the shape occupancy wants: "31 of 40" is a fraction, and a fraction
/// drawn as a fraction is read in one glance where a sentence has to be parsed.
class AppProgressRing extends StatelessWidget {
  const AppProgressRing({
    super.key,
    required this.value,
    this.size = 160,
    this.strokeWidth = 14,
    this.intent,
    this.center,
  });

  /// 0–1. Values outside that range are clamped rather than overdrawn.
  final double value;

  final double size;
  final double strokeWidth;

  /// Ring colour. Defaults to brand.
  final StatusIntent? intent;

  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color =
        intent == null ? t.brand.primary : t.status.of(intent!).solid;

    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
        duration: AppMotion.slow,
        curve: AppMotion.standard,
        builder: (context, animated, _) => CustomPaint(
          painter: _RingPainter(
            value: animated,
            color: color,
            track: t.surface.muted,
            strokeWidth: strokeWidth,
          ),
          child: Center(child: center),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.value,
    required this.color,
    required this.track,
    required this.strokeWidth,
  });

  final double value;
  final Color color;
  final Color track;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final centre = rect.center;
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;

    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = track;

    canvas.drawCircle(centre, radius, base);

    if (value <= 0) return;

    // Starts at twelve o'clock and runs clockwise, which is the direction a
    // reader assumes without being told.
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * value,
      false,
      base..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value || old.color != color || old.track != track;
}
