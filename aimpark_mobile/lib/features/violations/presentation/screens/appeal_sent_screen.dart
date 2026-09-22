import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../providers/violations_provider.dart';

/// The receipt for a submitted appeal.
///
/// A screen rather than a dialog, and deliberately not a celebration. Appealing
/// a fine is not a win — the charge is still open and the office has not
/// decided anything yet. The previous flow closed a sheet and popped a
/// congratulatory dialog, which left the user with no record of what had been
/// sent and a tone that did not match their situation.
///
/// What it owes the user is proof: what was sent, when, and against what.
class AppealSentScreen extends ConsumerWidget {
  const AppealSentScreen({super.key, required this.violationId});

  final String violationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final violation =
        ref.watch(violationDetailProvider(violationId)).valueOrNull;

    return AppScreen(
      showBack: false,
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const SizedBox(height: AppSpacing.lg),
          Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: t.status.info.bg,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_rounded,
                size: 34,
                color: t.status.info.fg,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Appeal received',
            textAlign: TextAlign.center,
            style: context.text.headlineLarge,
          ),
          const SizedBox(height: 6),
          Text(
            'We have your appeal. It is now with the parking office for '
            'review, and the violation stays open until they decide.',
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(color: t.text.secondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          AppFactsCard(
            facts: [
              const AppFact('Status', 'Under review'),
              AppFact('Submitted', Formatters.date(DateTime.now())),
              if (violation != null)
                AppFact(
                  'Violation',
                  '${violation.policyRuleTitle} · '
                      '${Formatters.peso(violation.penaltyAmount)}',
                ),
            ],
          ),
        ],
      ),
      bottomBar: AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppButton(
              label: 'Back to violations',
              // `go`, not `pop`: the form replaced itself with this screen, so
              // there is no sensible thing underneath to pop back to.
              onPressed: () => context.go('/home/user/violations'),
            ),
            const SizedBox(height: AppSpacing.xs),
            AppButton(
              label: 'Go home',
              style: AppButtonStyle.ghost,
              onPressed: () => context.go('/home/user'),
            ),
          ],
        ),
      ),
    );
  }
}
