import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';

/// A single headline number, for the Reports summary row and the dashboard.
///
/// The value uses tabular figures and the display size, so a row of tiles reads
/// as a set of comparable numbers rather than as eight unrelated captions.
///
/// [intent] still drives the fallback dot colour and the caption's tint, for
/// screens that mean "this number is a problem". [dotColor] overrides the dot
/// alone, for a row of tiles that are simply *different metrics* rather than
/// different severities — the reference dashboard gives each KPI tile its own
/// hue (blue, teal, green, red) regardless of whether anything is wrong.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.intent = StatusIntent.info,
    this.dotColor,
    this.caption,
    this.delta,
    this.deltaPositive = true,
    this.onTap,
    this.width = AppSizes.metricCardWidth,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusIntent intent;

  /// Overrides the leading dot's colour; falls back to the intent's solid.
  final Color? dotColor;

  /// Small line under the value — a comparison, a share, a rate.
  final String? caption;

  /// A period-over-period change, already formatted (e.g. "+6.4%"). Shown as
  /// a small pill beside the value. Omitted rather than guessed when the data
  /// doesn't support a real comparison.
  final String? delta;
  final bool deltaPositive;

  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;
    final dot = dotColor ?? c.solid;
    final deltaColors = deltaPositive ? t.status.success : t.status.danger;

    return AppCard(
      width: width,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // A dot rather than a filled icon square: the reference tile leads
          // with a small colour indicator and lets the number carry the
          // weight, instead of a coloured box competing with it for attention.
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.x2),
              Expanded(
                child: Text(
                  label,
                  style: text.bodySmall?.copyWith(color: t.text.secondary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (onTap != null)
                Icon(Icons.arrow_outward, size: 14, color: t.text.tertiary)
              else
                Icon(icon, size: AppSizes.iconSm, color: t.text.tertiary),
            ],
          ),
          const SizedBox(height: AppSpacing.x4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                value,
                style: AppTypography.tabular(text.displaySmall!),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (delta != null) ...[
                const SizedBox(width: AppSpacing.x2),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.x2, vertical: 2),
                  decoration: BoxDecoration(
                    color: deltaColors.bg,
                    borderRadius: AppRadii.fullAll,
                  ),
                  child: Text(
                    delta!,
                    style:
                        text.labelSmall?.copyWith(color: deltaColors.fg),
                  ),
                ),
              ],
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: AppSpacing.x1),
            Text(
              caption!,
              style: text.labelSmall?.copyWith(color: c.fg),
            ),
          ],
        ],
      ),
    );
  }
}
