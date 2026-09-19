import 'package:flutter/material.dart';

import '../../theme/theme.dart';

@immutable
class AppLevelDatum {
  const AppLevelDatum({
    required this.label,
    required this.valueLabel,
    required this.ratio,
    required this.color,
  });

  /// Printed under the bar — the category name.
  final String label;

  /// Printed above the bar — the reading itself.
  final String valueLabel;

  /// 0–1 fill.
  final double ratio;

  final Color color;
}

/// A row of capsule-shaped vertical bars — the reference dashboard's
/// per-sensor temperature read-out. Better suited than a bar chart to a
/// handful of independent gauges that don't share a category axis.
class AppLevelBars extends StatelessWidget {
  const AppLevelBars({super.key, required this.data, this.height = 110});

  final List<AppLevelDatum> data;
  final double height;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final d in data)
          Expanded(
            child: Column(
              children: [
                Text(d.valueLabel,
                    style: text.labelMedium?.copyWith(color: t.text.secondary)),
                const SizedBox(height: AppSpacing.x2),
                SizedBox(
                  height: height,
                  width: 22,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: d.ratio.clamp(0.0, 1.0)),
                    duration: AppMotion.slow,
                    curve: AppMotion.standard,
                    builder: (context, animated, _) => Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Color.lerp(d.color, t.surface.muted, 0.8),
                            borderRadius: AppRadii.fullAll,
                          ),
                        ),
                        // A visible floor rather than a near-invisible 2%
                        // sliver: a bar reading zero should still read as
                        // "this bar's colour", not as an empty grey capsule.
                        FractionallySizedBox(
                          heightFactor: animated <= 0.08 ? 0.08 : animated,
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Color.lerp(d.color, Colors.white, 0.45)!,
                                  d.color,
                                ],
                              ),
                              borderRadius: AppRadii.fullAll,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.x2),
                Text(d.label,
                    style: text.labelSmall?.copyWith(color: t.text.tertiary)),
              ],
            ),
          ),
      ],
    );
  }
}
