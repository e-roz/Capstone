import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/utils/responsive.dart';
import '../models/violation.dart';
import '../providers/violations_provider.dart';
import '../theme/theme.dart';
import 'document_viewer.dart';
import 'ui/ui.dart';

final _money = NumberFormat.currency(symbol: '₱', decimalDigits: 2);
final _when = DateFormat('MMM d, yyyy · h:mm a');

/// Opens the full record of one violation — the only place a violation is
/// decided.
///
/// Dismiss, Accept, Reject and Make Accountable all live here rather than on
/// table rows or appeal cards, so whoever decides has the user, the full rule,
/// the appeal and the history in front of them first. Deciding an appeal from
/// a card that showed only the user's text is how appeals used to be judged
/// blind.
Future<void> showViolationDetail(BuildContext context, String violationId) =>
    showDialog<void>(
      context: context,
      builder: (_) => _ViolationDetailDialog(violationId: violationId),
    );

class _ViolationDetailDialog extends ConsumerWidget {
  const _ViolationDetailDialog({required this.violationId});

  final String violationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(violationDetailProvider(violationId));

    return Dialog(
      insetPadding: const EdgeInsets.all(AppSpacing.x4),
      child: SizedBox(
        width: context.dialogWidth(760),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          child: AsyncView(
            value: detail,
            onRetry: () => ref.invalidate(violationDetailProvider(violationId)),
            loading: const Padding(
              padding: EdgeInsets.all(AppSpacing.x6),
              child: AppLoadingState(),
            ),
            data: (v) => _Body(v: v),
          ),
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  const _Body({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(
              AppSpacing.x5, AppSpacing.x5, AppSpacing.x3, AppSpacing.x3),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(v.policyRuleTitle, style: text.titleLarge),
                    const SizedBox(height: AppSpacing.labelGap),
                    Text(
                      '${v.userFullName} · issued ${_when.format(v.createdAt.toLocal())}',
                      style: text.bodySmall?.copyWith(color: t.text.secondary),
                    ),
                  ],
                ),
              ),
              ViolationStatusPill(status: v.status),
              const SizedBox(width: AppSpacing.x2),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.x5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _UserSection(v: v),
                const SizedBox(height: AppSpacing.x4),
                _RuleSection(v: v),
                const SizedBox(height: AppSpacing.x4),
                _ViolationSection(v: v),
                if (v.appealId != null) ...[
                  const SizedBox(height: AppSpacing.x4),
                  _AppealSection(v: v),
                ],
                const SizedBox(height: AppSpacing.x4),
                _TimelineSection(v: v),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(AppSpacing.x4),
          child: _Actions(v: v),
        ),
      ],
    );
  }
}

// ── Sections ─────────────────────────────────────────────────────────────────

class _UserSection extends StatelessWidget {
  const _UserSection({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context) {
    final strikes = v.accountableCount;
    const limit = ViolationStatuses.strikesBeforeRevoke;

    return AppSectionCard(
      title: 'User',
      icon: Icons.person_outline,
      child: AppFieldGrid(
        minColumnWidth: 160,
        fields: [
          AppField(label: 'Name', value: v.userFullName),
          AppField(label: 'Student no.', value: v.studentNumber ?? ''),
          AppField(
              label: 'RFID when issued',
              value: v.rfidTagIdAtIssue ?? v.rfidTagId ?? 'No card'),
          AppField(
              label: 'Card now',
              value: v.rfidTagId ??
                  (v.rfidStatus == 'Revoked' ? 'Revoked' : 'No card')),
          AppField(
            label: 'Accountable violations',
            child: StatusPill(
              label: '$strikes / $limit',
              intent: strikes >= limit
                  ? StatusIntent.danger
                  : strikes == limit - 1
                      ? StatusIntent.warning
                      : StatusIntent.neutral,
              dense: true,
              showDot: false,
            ),
          ),
        ],
      ),
    );
  }
}

/// The rule in full. Read-only: the rule is absolute, so this is what the
/// case is judged against, not something to adjust per case.
class _RuleSection extends StatelessWidget {
  const _RuleSection({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final rule = v.rule;

    return AppSectionCard(
      title: 'Policy rule',
      icon: Icons.policy_outlined,
      child: rule == null
          ? Text(v.policyRuleTitle)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(rule.title, style: text.titleSmall),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  rule.description.isEmpty
                      ? 'No description.'
                      : rule.description,
                  style: text.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.x4),
                AppFieldGrid(
                  minColumnWidth: 150,
                  fields: [
                    AppField(label: 'Category', value: rule.category),
                    AppField(
                        label: 'Penalty',
                        value: _money.format(rule.defaultPenaltyAmount)),
                    AppField(
                        label: 'Suspension',
                        value: _suspension(rule.defaultSuspensionType,
                            rule.defaultSuspensionDays)),
                    AppField(
                        label: 'Suspension starts',
                        value: rule.appealWindowDays == 0
                            ? 'Immediately'
                            : 'After ${rule.appealWindowDays} day(s)'),
                  ],
                ),
                if (!rule.isActive) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Text(
                    'This rule has since been deactivated.',
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                ],
              ],
            ),
    );
  }
}

class _ViolationSection extends StatelessWidget {
  const _ViolationSection({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'Violation',
      icon: Icons.gavel_outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(v.description, style: text.bodyMedium),
          const SizedBox(height: AppSpacing.x4),
          AppFieldGrid(
            minColumnWidth: 150,
            fields: [
              AppField(label: 'Penalty', value: _money.format(v.penaltyAmount)),
              AppField(
                  label: 'Suspension',
                  value: _suspension(v.suspensionType, v.suspensionDays)),
              AppField(
                label: 'Appeal until',
                value: v.appealDeadline == null
                    ? ''
                    : _when.format(v.appealDeadline!.toLocal()),
              ),
              AppField(
                label: 'Fine',
                child: v.paymentStatus == null
                    ? Text(
                        v.status == ViolationStatuses.accountable ||
                                v.penaltyAmount == 0
                            ? '—'
                            : 'Raised if accountable',
                        style: text.bodyMedium,
                      )
                    : StatusPill.of(
                        v.paymentStatus!,
                        intent: StatusIntents.payment(v.paymentStatus!),
                        dense: true,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppealSection extends StatelessWidget {
  const _AppealSection({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'Appeal',
      icon: Icons.record_voice_over_outlined,
      actions: [
        if (v.appealStatus != null)
          StatusPill.of(
            v.appealStatus!,
            intent: StatusIntents.violation(v.appealStatus!),
            dense: true,
          ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The user's argument is the thing being judged, so it gets the
          // quoted treatment rather than sitting as one more grey line.
          Container(
            padding: const EdgeInsets.all(AppSpacing.x3),
            decoration: BoxDecoration(
              color: t.surface.muted,
              borderRadius: AppRadii.smAll,
              border:
                  Border(left: BorderSide(color: t.border.strong, width: 3)),
            ),
            child: Text(v.appealReasonText ?? '', style: text.bodyMedium),
          ),
          if (v.appealEvidenceUrls.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text(
              'Evidence (${v.appealEvidenceUrls.length})',
              style: text.labelSmall?.copyWith(color: t.text.secondary),
            ),
            const SizedBox(height: AppSpacing.x2),
            AppealEvidenceStrip(urls: v.appealEvidenceUrls),
          ],
          if (v.appealAdminNotes case final notes? when notes.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.x3),
            Text('Admin notes: $notes',
                style: text.bodySmall?.copyWith(color: t.text.secondary)),
          ],
        ],
      ),
    );
  }
}

/// Every step of the case with when it happened and who did it.
class _TimelineSection extends StatelessWidget {
  const _TimelineSection({required this.v});

  final ViolationDetail v;

  @override
  Widget build(BuildContext context) {
    final events = <_Event>[
      _Event(v.createdAt, 'Issued', v.issuedByName, null),
      if (v.appealCreatedAt case final at?)
        _Event(at, 'User appealed', null, null),
      if (v.appealDecidedAt case final at?
          when v.appealStatus == 'Approved')
        _Event(at, 'Appeal accepted', v.appealDecidedByName,
            v.appealAdminNotes),
      if (v.dismissedAt case final at?)
        _Event(at, 'Dismissed', v.dismissedByName, v.dismissReason),
      if (v.accountableAt case final at?)
        _Event(at, 'Became accountable', v.accountableByName ?? 'System',
            v.accountableReason),
      if (v.paidAt case final at?) _Event(at, 'Fine paid', null, null),
      if (v.rfidRevokedAt case final at?)
        _Event(at, 'RFID card revoked (3 accountable violations)', null, null),
    ]..sort((a, b) => a.at.compareTo(b.at));

    return AppSectionCard(
      title: 'Timeline',
      icon: Icons.history,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, e) in events.indexed)
            _TimelineRow(event: e, isLast: i == events.length - 1),
        ],
      ),
    );
  }
}

class _Event {
  const _Event(this.at, this.title, this.by, this.note);

  final DateTime at;
  final String title;
  final String? by;
  final String? note;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final _Event event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 20,
            child: Column(
              children: [
                const SizedBox(height: 5),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: t.text.secondary,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 1, color: t.border.normal),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.x2),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.x3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(event.title, style: text.titleSmall),
                  Text(
                    [
                      _when.format(event.at.toLocal()),
                      if (event.by != null) 'by ${event.by}',
                    ].join(' · '),
                    style: text.bodySmall?.copyWith(color: t.text.secondary),
                  ),
                  if (event.note case final note? when note.isNotEmpty)
                    Text(note, style: text.bodySmall),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Actions ──────────────────────────────────────────────────────────────────

class _Actions extends ConsumerWidget {
  const _Actions({required this.v});

  final ViolationDetail v;

  /// Whether making this one accountable would be the user's third strike
  /// and take their card.
  bool get _wouldRevoke =>
      v.rfidTagId != null &&
      v.accountableCount + 1 >= ViolationStatuses.strikesBeforeRevoke;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final busy = ref.watch(violationActionsProvider).isLoading;

    final buttons = <Widget>[
      if (v.status == ViolationStatuses.issued ||
          v.status == ViolationStatuses.pendingAppeal)
        AppRowAction(
          label: 'Dismiss',
          icon: Icons.block,
          onPressed: busy ? null : () => _dismiss(context, ref),
        ),
      if (v.status == ViolationStatuses.issued)
        AppRowAction(
          label: 'Make Accountable',
          icon: Icons.gavel,
          intent: StatusIntent.danger,
          onPressed: busy ? null : () => _makeAccountable(context, ref),
        ),
      if (v.status == ViolationStatuses.pendingAppeal &&
          v.appealId != null) ...[
        AppRowAction(
          label: 'Reject appeal',
          icon: Icons.close,
          intent: StatusIntent.danger,
          onPressed: busy ? null : () => _decide(context, ref, false),
        ),
        AppRowAction(
          label: 'Accept appeal',
          icon: Icons.check,
          intent: StatusIntent.success,
          onPressed: busy ? null : () => _decide(context, ref, true),
        ),
      ],
    ];

    return Row(
      children: [
        Expanded(
          child: Text(
            switch (v.status) {
              ViolationStatuses.issued =>
                'Waiting on the user. Becomes accountable automatically if not appealed by the deadline.',
              ViolationStatuses.pendingAppeal =>
                'The user has appealed. Accept, reject, or dismiss if it was issued by mistake.',
              _ => 'This case is closed.',
            },
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ),
        for (final b in buttons) ...[
          const SizedBox(width: AppSpacing.controlGap),
          b,
        ],
      ],
    );
  }

  Future<void> _dismiss(BuildContext context, WidgetRef ref) async {
    final reason = await _confirm(
      context,
      title: 'Dismiss violation?',
      message: 'Use this when the violation was issued by mistake. '
          '${v.userFullName} will have no penalty and any suspension from it '
          'is lifted${v.appealId != null ? '. Their pending appeal is closed' : ''}. '
          'This cannot be undone.',
      reasonLabel: 'Reason for dismissing',
      actionLabel: 'Yes, dismiss',
      danger: false,
    );
    if (reason == null || !context.mounted) return;
    await _finish(context, ref,
        ref.read(violationActionsProvider.notifier).dismiss(v.violationId, reason));
  }

  Future<void> _makeAccountable(BuildContext context, WidgetRef ref) async {
    final reason = await _confirm(
      context,
      title: 'Make user accountable now?',
      message: 'This skips the rest of the appeal period. ${v.userFullName} '
          'can no longer appeal, the ${_money.format(v.penaltyAmount)} fine is '
          'raised, and any suspension starts now. This cannot be undone.',
      warning: _wouldRevoke ? _revokeWarning : null,
      reasonLabel: 'Reason',
      actionLabel: 'Yes, make accountable',
      danger: true,
    );
    if (reason == null || !context.mounted) return;
    await _finish(
        context,
        ref,
        ref
            .read(violationActionsProvider.notifier)
            .makeAccountable(v.violationId, reason));
  }

  Future<void> _decide(BuildContext context, WidgetRef ref, bool accept) async {
    final reason = await _confirm(
      context,
      title: accept ? 'Accept appeal?' : 'Reject appeal?',
      message: accept
          ? 'The user is proven right. The violation is cleared, no fine is '
              'raised, and any suspension from it is lifted.'
          : 'The appeal is not enough. The user becomes accountable: the '
              '${_money.format(v.penaltyAmount)} fine is raised and the rule\'s '
              'suspension starts now.',
      warning: !accept && _wouldRevoke ? _revokeWarning : null,
      reasonLabel: accept ? 'Notes for the user (optional)' : 'Reason (shown to the user)',
      reasonRequired: !accept,
      actionLabel: accept ? 'Yes, accept' : 'Yes, reject',
      danger: !accept,
    );
    if (reason == null || !context.mounted) return;
    await _finish(
        context,
        ref,
        ref.read(violationActionsProvider.notifier).decideAppeal(
            v.appealId!, accept, reason.isEmpty ? null : reason));
  }

  String get _revokeWarning =>
      'This will be ${v.userFullName}\'s ${ViolationStatuses.strikesBeforeRevoke}rd '
      'accountable violation. Their RFID card (${v.rfidTagId}) will be revoked.';

  Future<void> _finish(
      BuildContext context, WidgetRef ref, Future<String?> action) async {
    final msg = await action;
    ref.invalidate(violationDetailProvider(v.violationId));
    ref.invalidate(violationListProvider);
    ref.invalidate(violationLogListProvider);
    ref.invalidate(appealListProvider);
    ref.invalidate(pendingAppealCountProvider);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg ?? 'Done.')));
  }
}

/// The "are you sure?" step every decision goes through. Returns the reason
/// typed, or null when cancelled.
Future<String?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String reasonLabel,
  required String actionLabel,
  required bool danger,
  bool reasonRequired = true,
  String? warning,
}) {
  final ctrl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final t = ctx.tokens;
      final text = Theme.of(ctx).textTheme;
      return AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: ctx.dialogWidth(440),
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message),
                if (warning != null) ...[
                  const SizedBox(height: AppSpacing.x3),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.x3),
                    decoration: BoxDecoration(
                      color: t.status.danger.bg,
                      borderRadius: AppRadii.smAll,
                      border: Border.all(color: t.status.danger.border),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: AppSizes.iconSm, color: t.status.danger.fg),
                        const SizedBox(width: AppSpacing.x2),
                        Expanded(
                          child: Text(warning,
                              style: text.bodySmall
                                  ?.copyWith(color: t.status.danger.fg)),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: AppSpacing.x4),
                TextFormField(
                  controller: ctrl,
                  autofocus: true,
                  maxLines: 2,
                  decoration: InputDecoration(
                    label: AppFieldLabel(reasonLabel,
                        isRequired: reasonRequired),
                  ),
                  validator: (val) =>
                      reasonRequired && (val == null || val.trim().isEmpty)
                          ? 'A reason is required'
                          : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: t.status.danger.solid)
                : null,
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, ctrl.text.trim());
              }
            },
            child: Text(actionLabel),
          ),
        ],
      );
    },
  );
}

String _suspension(String type, int? days) => switch (type) {
      'Temporary' when days != null =>
        'Temporary · $days ${days == 1 ? 'day' : 'days'}',
      'None' || '' => 'None',
      _ => type,
    };

// ── Shared pieces ────────────────────────────────────────────────────────────

/// A violation status pill with its readable label ("Pending Appeal", not
/// "PendingAppeal").
class ViolationStatusPill extends StatelessWidget {
  const ViolationStatusPill({super.key, required this.status, this.dense = true});

  final String status;
  final bool dense;

  @override
  Widget build(BuildContext context) => StatusPill(
        label: ViolationStatuses.label(status),
        intent: StatusIntents.violation(status),
        dense: dense,
      );
}

/// The appeal's photographs, as a row of thumbnails that open full size.
///
/// Thumbnails rather than a list of links: an admin deciding an appeal is
/// looking for whether the photo shows what the text claims, and a filename
/// tells them nothing about that. Clicking one opens the existing viewer, so
/// this behaves like the registration documents do.
class AppealEvidenceStrip extends StatelessWidget {
  const AppealEvidenceStrip({super.key, required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Wrap(
      spacing: AppSpacing.x2,
      runSpacing: AppSpacing.x2,
      children: [
        for (final (i, url) in urls.indexed)
          Tooltip(
            message: 'Open photo ${i + 1}',
            child: InkWell(
              onTap: () => viewDocument(
                context,
                title: 'Appeal evidence ${i + 1}',
                // The signed URL carries a query string, so the extension has
                // to be read off the path rather than the whole thing —
                // otherwise every image is mistaken for a PDF and opens in a
                // new tab instead of the viewer.
                fileName: Uri.parse(url).path,
                url: url,
              ),
              borderRadius: AppRadii.smAll,
              child: Container(
                width: 92,
                height: 92,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: t.surface.muted,
                  borderRadius: AppRadii.smAll,
                  border: Border.all(color: t.border.normal),
                ),
                child: Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.broken_image_outlined,
                    color: t.text.tertiary,
                  ),
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
