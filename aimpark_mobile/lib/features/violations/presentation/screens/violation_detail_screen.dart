import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/widgets.dart';
import '../../data/models/violation.dart';
import '../providers/violations_provider.dart';

class ViolationDetailScreen extends ConsumerWidget {
  const ViolationDetailScreen({super.key, required this.violationId});

  final String violationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppScreen(
      title: 'Violation Detail',
      body: AsyncView(
        value: ref.watch(violationDetailProvider(violationId)),
        onRefresh: () {
          ref.invalidate(violationDetailProvider(violationId));
          return ref.read(violationDetailProvider(violationId).future);
        },
        errorTitle: "Couldn't load this violation",
        data: (violation) => ListView(
          padding: kScreenListPadding,
          children: [
            _StatusCard(violation: violation),
            const SizedBox(height: AppSpacing.gutter),
            AppFactsCard(
              title: 'Recorded facts',
              facts: [
                AppFact('Issued', Formatters.date(violation.createdAt)),
                AppFact(
                  'Suspension',
                  violation.suspensionDays != null
                      ? '${violation.suspensionType} · '
                            '${violation.suspensionDays} day(s)'
                      : violation.suspensionType,
                ),
                if (violation.isPaid)
                  AppFact(
                    'Paid',
                    violation.paidAt != null
                        ? Formatters.date(violation.paidAt!)
                        : 'Settled',
                    intent: StatusIntent.success,
                  )
                else if (violation.isWaived)
                  const AppFact('Payment', 'Waived', intent: StatusIntent.info)
                else if (violation.isPayable && violation.paymentDueAt != null)
                  AppFact(
                    'Due by',
                    Formatters.date(violation.paymentDueAt!),
                    intent: StatusIntent.warning,
                  ),
              ],
              // Only red while it is still owed. Colouring a settled fine as a
              // problem is how a paid violation kept reading like an unpaid one.
              total: AppFact(
                'Penalty',
                Formatters.peso(violation.penaltyAmount),
                intent: violation.isPayable ? StatusIntent.danger : null,
              ),
            ),
            const SizedBox(height: AppSpacing.gutter),
            AppRowGroup(
              children: [
                AppListRow(
                  title: 'Read the policy this cites',
                  onTap: () => context.push(
                    '/home/user/policy?rule='
                    '${Uri.encodeQueryComponent(violation.policyRuleTitle)}',
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (violation.appealStatus != null)
              _AppealCard(violation: violation)
            else
              AppButton(
                label: 'Appeal this violation',
                style: AppButtonStyle.ghost,
                onPressed: () =>
                    context.push('/home/user/violations/$violationId/appeal'),
              ),
          ],
        ),
      ),
    );
  }
}

/// What state this violation is in, and what that means for the user.
///
/// A tinted card rather than a badge tucked beside the title. The status is the
/// first thing anyone opening this screen wants, and it decides whether the
/// buttons below say "appeal" or "nothing to do" — a pill in the corner was
/// carrying more weight than its size suggested.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.violation});

  final ViolationDetail violation;

  /// Says what the state means, not just what it is called. "Appealed" tells a
  /// user nothing about whether they still owe the money; this does.
  String get _line {
    if (violation.isWaived) {
      return 'The charge was waived. This record stays on file but needs '
          'nothing from you.';
    }
    if (violation.isPaid) {
      return 'Paid. This record stays on file but needs nothing from you.';
    }
    if (violation.appealStatus != null) {
      return 'Your appeal is with the parking office. The violation stays open '
          'until they decide.';
    }
    return 'This violation is open. You can pay it or appeal it. Your access '
        'is unaffected while it is open.';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(
      StatusIntents.violation(violation.displayStatus),
    );

    return AppCard(
      color: c.bg,
      borderColor: c.border,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: c.fg, shape: BoxShape.circle),
              ),
              const SizedBox(width: AppSpacing.xs + 2),
              Flexible(
                child: Text(
                  violation.displayStatus.toUpperCase(),
                  style: context.text.labelMedium?.copyWith(color: c.fg),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(violation.policyRuleTitle, style: context.text.headlineSmall),
          const SizedBox(height: 2),
          Text(violation.description, style: context.text.bodyMedium),
          const SizedBox(height: AppSpacing.sm),
          Text(_line, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// The appeal the user already submitted, and where it got to.
class _AppealCard extends StatelessWidget {
  const _AppealCard({required this.violation});

  final ViolationDetail violation;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppSectionHeader(title: 'Appeal'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppStatusBadge(
                label: violation.appealStatus!,
                intent: StatusIntents.violation(violation.appealStatus!),
              ),
              if (violation.appealReasonText != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  violation.appealReasonText!,
                  style: context.text.bodyMedium,
                ),
              ],
              if (violation.appealEvidenceUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Evidence you submitted', style: context.text.labelSmall),
                const SizedBox(height: AppSpacing.xs),
                SizedBox(
                  height: 90,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: violation.appealEvidenceUrls.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(width: AppSpacing.sm),
                    itemBuilder: (context, index) => ClipRRect(
                      borderRadius: AppRadius.smAll,
                      child: Image.network(
                        violation.appealEvidenceUrls[index],
                        width: 90,
                        height: 90,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          width: 90,
                          height: 90,
                          color: t.surface.muted,
                          child: Icon(
                            Icons.broken_image_rounded,
                            color: t.text.secondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              if (violation.appealAdminNotes != null) ...[
                const SizedBox(height: AppSpacing.sm),
                Text('Admin notes', style: context.text.labelSmall),
                Text(
                  violation.appealAdminNotes!,
                  style: context.text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
