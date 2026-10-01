import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// An icon and a number in a tinted pill — the dashboard header's currency.
///
/// [PointsCounter] and [StreakBadge] were two files that differed only in which
/// icon and which hue they picked, and their padding had already drifted apart
/// by two pixels. They are now both this widget with an accent passed in.
class StatPill extends StatelessWidget {
  const StatPill({
    super.key,
    required this.icon,
    required this.value,
    required this.accent,
    this.semanticLabel,
  });

  final IconData icon;
  final String value;

  /// Which of the app's three hues carries this stat. Pass a token group —
  /// `context.tokens.brand`, `.tertiary` — rather than a raw colour.
  final AppAccentTokens accent;

  /// What a screen reader announces. Without it the pill reads as a bare
  /// number with no idea what is being counted.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: accent.subtle,
          borderRadius: AppRadius.fullAll,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent.subtleText, size: AppSizes.iconMd),
            const SizedBox(width: AppSpacing.xs),
            Text(
              value,
              // Tabular figures: these sit in a fixed row in the header and
              // animate as data lands, so proportional digits make the whole
              // pill visibly resize when 9 becomes 10.
              style: AppTypography.tabular(
                context.text.labelMedium!.copyWith(
                  color: accent.subtleText,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Parking Points — earned for on-time entry/exit, correct zone, and rule
/// adherence. AimPark's XP equivalent.
class PointsCounter extends StatelessWidget {
  const PointsCounter({super.key, required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    return StatPill(
      icon: Icons.star_rounded,
      value: '$points',
      accent: context.tokens.brand,
      semanticLabel: '$points parking points',
    );
  }
}

/// Consecutive-day compliance streak — AimPark's answer to Duolingo's daily
/// streak. Counts days parked without a violation.
class StreakBadge extends StatelessWidget {
  const StreakBadge({super.key, required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return StatPill(
      icon: Icons.local_fire_department_rounded,
      value: '$days',
      accent: context.tokens.tertiary,
      semanticLabel: days == 1 ? '1 day streak' : '$days day streak',
    );
  }
}
