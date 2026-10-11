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

  void _openPhoto(BuildContext context, List<String> urls, int index) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => PhotoViewerScreen(urls: urls, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(violationDetailProvider(violationId));
    final violation = async.valueOrNull;

    return AppScreen(
      title: 'Violation Detail',
      // The one thing to do about a violation, pinned where a thumb already is.
      // It was an outline button floating in the middle of the page, the quietest
      // thing on a screen that otherwise shouted — for the only action with a
      // deadline attached.
      bottomBar: violation == null ? null : _actionBar(context, violation),
      body: AsyncView(
        value: async,
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
                if (violation.canAppeal && violation.appealDeadline != null)
                  AppFact(
                    'Appeal until',
                    Formatters.date(violation.appealDeadline!),
                    intent: appealUrgency(violation.appealDeadline!),
                  ),
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
                else if (violation.isPayable)
                  const AppFact(
                    'Payment',
                    'Due now',
                    intent: StatusIntent.warning,
                  ),
              ],
              total: _penalty(violation),
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
            if (violation.appealStatus != null) ...[
              const SizedBox(height: AppSpacing.lg),
              _AppealSection(
                violation: violation,
                onPhoto: (i) =>
                    _openPhoto(context, violation.appealEvidenceUrls, i),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// The penalty line. A penalty that does not apply — the appeal was accepted,
  /// the violation dismissed, the charge waived — is shown struck through with
  /// "Not charged". Printing it at full size and in bold, directly under a green
  /// banner saying "No penalty applies", made the screen contradict itself.
  AppFact _penalty(ViolationDetail v) {
    final status = v.status.toLowerCase();
    final notCharged =
        v.isWaived || status == 'appealed' || status == 'dismissed';

    if (notCharged) {
      return AppFact(
        'Penalty',
        Formatters.peso(v.penaltyAmount),
        struck: true,
        note: 'Not charged',
        intent: StatusIntent.success,
      );
    }
    return AppFact(
      'Penalty',
      Formatters.peso(v.penaltyAmount),
      intent: v.isPayable ? StatusIntent.danger : null,
    );
  }

  Widget? _actionBar(BuildContext context, ViolationDetail v) {
    if (v.canAppeal) {
      final deadline = v.appealDeadline;
      final urgency = deadline == null ? null : appealUrgency(deadline);
      final fg = urgency == null
          ? null
          : context.tokens.status.of(urgency).fg;

      return AppBottomBar(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (deadline != null) ...[
              Text(
                '${appealCountdown(deadline)} · by ${Formatters.date(deadline)}',
                textAlign: TextAlign.center,
                style: context.text.bodySmall?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
            ],
            AppButton(
              label: 'Appeal this violation',
              onPressed: () =>
                  context.push('/home/user/violations/$violationId/appeal'),
            ),
          ],
        ),
      );
    }

    // Final and unpaid: the way to settle it is one tap away, to the bill, where
    // the payer sees what they owe before choosing to pay.
    if (v.isPayable && v.paymentId != null) {
      return AppBottomBar(
        child: AppButton(
          label: 'Pay ${Formatters.peso(v.amountDue ?? v.penaltyAmount)}',
          onPressed: () => context.push('/home/user/payments/${v.paymentId}'),
        ),
      );
    }
    return null;
  }
}

/// What state this violation is in, and what that means for the user.
///
/// A tinted card rather than a badge tucked beside the title. The status is the
/// first thing anyone opening this screen wants, and it decides whether the
/// buttons below say "appeal" or "nothing to do" — a pill in the corner was
/// carrying more weight than its size suggested.
///
/// Open and still appealable, it is amber and turns red in the last day, with the
/// time left in bold. It used to be calm blue: information, for a charge with a
/// deadline.
class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.violation});

  final ViolationDetail violation;

  StatusIntent get _intent {
    if (violation.isWaived) return StatusIntent.info;
    if (violation.isPaid) return StatusIntent.success;
    final deadline = violation.appealDeadline;
    if (violation.status.toLowerCase() == 'issued') {
      return deadline == null ? StatusIntent.warning : appealUrgency(deadline);
    }
    return StatusIntents.violation(violation.displayStatus);
  }

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
    switch (violation.status.toLowerCase()) {
      case 'pendingappeal':
        return 'Your appeal is with the parking office. Nothing is charged '
            'until they decide.';
      case 'appealed':
        return 'Your appeal was accepted. No penalty applies.';
      case 'dismissed':
        return 'This violation was dismissed. No penalty applies.';
      case 'accountable':
        return violation.isPayable
            ? 'This violation is final. Please pay the penalty.'
            : 'This violation is final.';
    }
    final deadline = violation.appealDeadline;
    if (deadline != null && DateTime.now().isAfter(deadline)) {
      return 'The appeal period has ended. This violation will become final '
          'shortly.';
    }
    return 'This violation is open. Appeal before the deadline, or it becomes '
        'final and the penalty is charged.';
  }

  @override
  Widget build(BuildContext context) {
    final intent = _intent;
    final c = context.tokens.status.of(intent);
    final deadline = violation.canAppeal ? violation.appealDeadline : null;

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
          // The time left, as the loudest line in the card: it is the one fact
          // here that is running out.
          if (deadline != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Icon(Icons.timer_outlined, size: AppSizes.iconMd, color: c.fg),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    appealCountdown(deadline),
                    style: context.text.titleMedium?.copyWith(
                      color: c.fg,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Text(_line, style: context.text.bodySmall),
        ],
      ),
    );
  }
}

/// The appeal the user already submitted, and where it got to.
class _AppealSection extends StatelessWidget {
  const _AppealSection({required this.violation, required this.onPhoto});

  final ViolationDetail violation;
  final ValueChanged<int> onPhoto;

  @override
  Widget build(BuildContext context) {
    final decided = violation.appealDecidedAt;
    final notes = violation.appealAdminNotes?.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AppSectionHeader(title: 'Your appeal'),
        // Full width, like every other card here. It was sized to its content, so
        // a short appeal left a card half as wide as the rest of the screen.
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AppStatusBadge(
                    label: violation.appealStatus!,
                    intent: StatusIntents.violation(violation.appealStatus!),
                    showDot: true,
                  ),
                  if (decided != null) ...[
                    const SizedBox(width: AppSpacing.sm),
                    Flexible(
                      child: Text(
                        'Decided ${Formatters.date(decided.toLocal())}',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ],
              ),
              if (violation.appealReasonText != null) ...[
                const SizedBox(height: AppSpacing.md),
                AppInfoRow(
                  label: 'What you wrote',
                  value: violation.appealReasonText!,
                ),
              ],
              if (violation.appealEvidenceUrls.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                Text('Evidence you sent', style: context.text.labelSmall),
                const SizedBox(height: AppSpacing.sm),
                AppPhotoThumb.grid(
                  urls: violation.appealEvidenceUrls,
                  onTap: onPhoto,
                ),
              ],
            ],
          ),
        ),
        if (notes != null && notes.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          AppAlertCard(
            intent: StatusIntent.brand,
            icon: Icons.support_agent_rounded,
            eyebrow: 'Note from the parking office',
            message: notes,
          ),
        ],
      ],
    );
  }
}
