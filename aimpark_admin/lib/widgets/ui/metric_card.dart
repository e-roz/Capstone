import 'package:flutter/material.dart';

import '../../theme/theme.dart';
import 'app_card.dart';

/// A single headline number, for the Reports summary row.
///
/// The value uses tabular figures and the display size, so a row of tiles reads
/// as a set of comparable numbers rather than as eight unrelated captions.
///
/// Colour comes from a [StatusIntent] rather than a raw `Color`: "Open
/// Incidents" is a *warning*, not "orange", and stating the intent means dark
/// mode and future palette changes follow automatically.
class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.intent = StatusIntent.info,
    this.caption,
    this.onTap,
    this.width = AppSizes.metricCardWidth,
  });

  final String label;
  final String value;
  final IconData icon;
  final StatusIntent intent;

  /// Small line under the value — a comparison, a share, a rate.
  final String? caption;

  final VoidCallback? onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.of(intent);
    final text = Theme.of(context).textTheme;

    return AppCard(
      width: width,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Icon and value share the top line, with the number pushed right.
          // Stacked under the icon, the value sat in the tile's dead centre-left
          // and read as just another line of text; on its own end of the row it
          // is unmistakably the thing the tile is about, and a row of tiles
          // gives you a column of numbers to compare down.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: c.bg,
                  borderRadius: AppRadii.smAll,
                ),
                child: Icon(icon, size: AppSizes.iconMd, color: c.fg),
              ),
              const SizedBox(width: AppSpacing.x3),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: AppTypography.tabular(text.displaySmall!),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.x3),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: t.text.secondary),
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
