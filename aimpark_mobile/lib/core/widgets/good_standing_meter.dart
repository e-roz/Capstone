import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_progress_bar.dart';

/// Replaces Duolingo's "hearts" mechanic with an opposite-psychology meter:
/// it builds up with compliant parking rather than draining on mistakes, and
/// never blocks access — it's a trust signal, not a gate. See design notes:
/// a parking violation already has real consequences (fines/suspension)
/// handled elsewhere, so the UI shouldn't add punitive game-feel on top.
class GoodStandingMeter extends StatelessWidget {
  const GoodStandingMeter({
    super.key,
    required this.level,
    required this.tierLabel,
  });

  /// 0.0–1.0 fill amount.
  final double level;
  final String tierLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.success;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Good Standing', style: context.text.labelSmall),
            Text(
              tierLabel,
              style: context.text.labelMedium?.copyWith(color: c.fg),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        AppProgressBar(
          value: level,
          height: 10,
          color: c.solid,
          trackColor: c.bg,
        ),
      ],
    );
  }
}
