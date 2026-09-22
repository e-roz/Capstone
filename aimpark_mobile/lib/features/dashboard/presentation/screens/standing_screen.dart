import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../violations/presentation/providers/violations_provider.dart';
import '../../domain/standing.dart';

/// The one plain explanation of standing, points and streaks.
///
/// Gamification gets exactly one page, and it states consequences rather than
/// implying them. The dashboard shows a tier and two counters with no way to
/// find out what any of it means or whether it affects anything — which is how
/// a number nobody can interpret starts to feel like a threat.
class StandingScreen extends ConsumerWidget {
  const StandingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Degrades rather than erroring. This page is readable with no data at all;
    // the only thing the violations list adds is which tier to mark as yours.
    final yours =
        Standing.tierFor(ref.watch(violationsNotifierProvider).valueOrNull);

    return AppScreen(
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const AppScreenTitle(title: 'How standing works'),
          Text(
            'Standing is a plain summary of your violation record. It does not '
            'change your parking rate, and it is not a score you have to '
            'manage.',
            style: context.text.bodyMedium
                ?.copyWith(color: context.tokens.text.secondary),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final tier in StandingTier.values) ...[
            _TierCard(tier: tier, isYours: tier == yours),
            if (tier != StandingTier.values.last)
              const SizedBox(height: AppSpacing.gutter),
          ],
          const SizedBox(height: AppSpacing.lg),
          const AppSectionHeader(title: 'Points and streak'),
          const _PointsCard(),
        ],
      ),
    );
  }
}

class _TierCard extends StatelessWidget {
  const _TierCard({required this.tier, required this.isYours});

  final StandingTier tier;
  final bool isYours;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final intent =
        tier == StandingTier.gold ? StatusIntent.success : StatusIntent.warning;

    return AppCard(
      // Only your own tier is outlined. Outlining all three would make the page
      // look like a set of options to choose between rather than a scale you
      // are already somewhere on.
      borderColor: isYours ? t.brand.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StatusDot(intent: intent, size: 10),
              const SizedBox(width: AppSpacing.xs + 2),
              Expanded(
                child: Text(tier.label, style: context.text.titleMedium),
              ),
              if (isYours)
                const AppStatusBadge(
                  label: 'You are here',
                  intent: StatusIntent.brand,
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(tier.rule, style: context.text.bodySmall),
          const SizedBox(height: 6),
          Text(tier.effect, style: context.text.bodyMedium),
        ],
      ),
    );
  }
}

class _PointsCard extends StatelessWidget {
  const _PointsCard();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    // Read from the same constants the dashboard counts with, so the
    // explanation cannot drift away from the arithmetic it describes.
    final rules = [
      '+${Standing.pointsPerSession} points for each completed parking '
          'session.',
      '+${Standing.pointsPerStreakWeek} points when you reach a '
          '${Standing.streakWeekDays}-day streak.',
      'A streak is consecutive days with a session and no violation issued.',
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in rules) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  margin: const EdgeInsets.only(top: 8),
                  decoration: BoxDecoration(
                    color: t.brand.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(rule, style: context.text.bodyMedium)),
              ],
            ),
            if (rule != rules.last) const SizedBox(height: 10),
          ],
          const SizedBox(height: AppSpacing.sm + 6),
          Divider(height: 1, thickness: 1, color: t.border.subtle),
          const SizedBox(height: AppSpacing.sm + 6),
          // Said out loud rather than buried. These values were chosen by the
          // app, not by the parking office, and presenting an unconfirmed rule
          // as settled policy is the part that would actually mislead someone.
          Text(
            'Point values and tier thresholds shown here are the values the app '
            'currently uses. They are pending confirmation with the parking '
            'office and may change.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
