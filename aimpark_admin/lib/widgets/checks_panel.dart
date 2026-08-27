import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';
import '../models/registration_checks.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The evidence panel on the registration review screen.
///
/// The API already ran these checks at submission time; for most of this
/// project's life it kept the answers to itself and the reviewer re-did every
/// comparison by eye. These widgets are that work, made visible.
///
/// They report and never decide. Nothing here enables or disables Approve, and
/// a card of green ticks means only that nothing contradicted itself — whether
/// the documents are genuine is a question no rule in this system can answer.

// ── State → colour ───────────────────────────────────────────────────────────

/// How each state reads.
///
/// [CheckState.notChecked] is deliberately neutral, not red. A value that could
/// not be read is the reason a human is looking at this at all; painting it as
/// a failure would push reviewers to reject applications whose only sin was a
/// dim photo.
StatusIntent _intentOf(CheckState state) => switch (state) {
      CheckState.passed => StatusIntent.success,
      CheckState.expiringSoon => StatusIntent.warning,
      CheckState.failed => StatusIntent.danger,
      CheckState.notChecked => StatusIntent.neutral,
    };

IconData _iconOf(CheckState state) => switch (state) {
      CheckState.passed => Icons.check,
      CheckState.expiringSoon => Icons.priority_high,
      CheckState.failed => Icons.close,
      CheckState.notChecked => Icons.remove,
    };

// ── Verdict banner ───────────────────────────────────────────────────────────

/// The summary that sits above everything else on the review screen.
///
/// It is the first thing read and the last thing that should be mistaken for a
/// decision, so it always ends by saying whose call this is.
class ChecksVerdictBanner extends StatelessWidget {
  const ChecksVerdictBanner({super.key, required this.checks});

  final RegistrationChecks checks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final intent = switch (checks.verdict) {
      'LookCloser' => StatusIntent.warning,
      'Clear' => StatusIntent.success,
      _ => StatusIntent.neutral,
    };
    final c = t.status.of(intent);

    final icon = switch (checks.verdict) {
      'LookCloser' => Icons.priority_high,
      'Clear' => Icons.check,
      _ => Icons.help_outline,
    };

    return Container(
      padding: const EdgeInsets.all(AppSpacing.cardPadding),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.bannerIcon,
            height: AppSizes.bannerIcon,
            decoration: BoxDecoration(
              color: c.solid,
              borderRadius: AppRadii.mdAll,
            ),
            child: Icon(icon, size: AppSizes.iconMd, color: t.text.onBrand),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checks.summary,
                  style: text.titleSmall?.copyWith(color: c.fg),
                ),
                if (checks.headlines.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  for (final headline in checks.headlines)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.x1),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 7, right: 8),
                            child: Container(
                              width: 4,
                              height: 4,
                              decoration: BoxDecoration(
                                color: t.text.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(headline, style: text.bodySmall),
                          ),
                        ],
                      ),
                    ),
                ],
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'This is a summary, not a decision. Approve and Reject are still yours.',
                  style: text.labelSmall?.copyWith(color: t.text.tertiary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── One group of checks ──────────────────────────────────────────────────────

/// The person's checks, or one vehicle's.
///
/// Split by subject rather than by stored row: a submission that only adds a
/// second vehicle carries no name or licence readings, and replaying it row by
/// row would report "could not compare names" about documents that were read
/// perfectly well on an earlier submission.
class CheckGroupCard extends StatelessWidget {
  const CheckGroupCard({super.key, required this.group});

  final CheckGroup group;

  @override
  Widget build(BuildContext context) {
    return AppSectionCard(
      title: group.title,
      subtitle: group.source,
      icon: Icons.rule,
      child: Column(
        children: [
          for (final (i, check) in group.checks.indexed)
            _CheckRow(check: check, isFirst: i == 0),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.check, required this.isFirst});

  final CheckItem check;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(_intentOf(check.state));
    final compact = context.isCompact;

    final mark = Container(
      width: AppSizes.iconMd,
      height: AppSizes.iconMd,
      decoration: BoxDecoration(
        color: c.bg,
        shape: BoxShape.circle,
        border: Border.all(color: c.border),
      ),
      child: Icon(_iconOf(check.state), size: 12, color: c.fg),
    );

    final label = Text(check.label, style: text.titleSmall);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (check.detail case final detail?)
          Text(
            detail,
            // Failures and deadlines are tinted; everything else stays body
            // colour so the row does not shout about a semester being read.
            style: text.bodySmall?.copyWith(
              color: switch (check.state) {
                CheckState.failed || CheckState.expiringSoon => c.fg,
                _ => t.text.secondary,
              },
            ),
          ),
        if (check.values.isNotEmpty) ...[
          if (check.detail != null) const SizedBox(height: AppSpacing.x1),
          // The evidence itself. A reviewer who disagrees with a verdict needs
          // to see what was compared, not just be told the answer.
          Wrap(
            spacing: AppSpacing.x3,
            runSpacing: AppSpacing.x1,
            children: [
              for (final value in check.values)
                RichText(
                  text: TextSpan(
                    style: text.bodySmall?.copyWith(color: t.text.tertiary),
                    children: [
                      TextSpan(text: '${value.label} '),
                      TextSpan(
                        text: value.value,
                        style: text.bodySmall?.copyWith(
                          color: t.text.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ],
    );

    return Container(
      padding: EdgeInsets.only(
        top: isFirst ? 0 : AppSpacing.x3,
        bottom: AppSpacing.x3,
      ),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : Border(top: BorderSide(color: t.border.subtle)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          mark,
          const SizedBox(width: AppSpacing.x3),
          // On a narrow window the label stacks above its evidence; side by side
          // it would leave the detail column too thin to read.
          if (compact)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  label,
                  const SizedBox(height: AppSpacing.x1),
                  body,
                ],
              ),
            )
          else ...[
            SizedBox(width: AppSizes.checkLabelWidth, child: label),
            const SizedBox(width: AppSpacing.x3),
            Expanded(child: body),
          ],
        ],
      ),
    );
  }
}

// ── What the applicant typed over ────────────────────────────────────────────

/// Values the applicant changed from what the phone read.
///
/// Its own card rather than more rows inside the person's, because an identity
/// field the applicant supplied themselves is the single strongest reason to
/// open the documents — and it would be lost as row seven of a list.
class ValueEditsCard extends StatelessWidget {
  const ValueEditsCard({super.key, required this.edits});

  final List<ValueEdit> edits;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return AppSectionCard(
      title: 'What the applicant changed',
      subtitle: 'Typed over what the phone read',
      icon: Icons.edit_note,
      child: Column(
        children: [
          for (final (i, edit) in edits.indexed)
            _CheckRow(
              isFirst: i == 0,
              check: CheckItem(
                key: 'Edit.${edit.field}',
                label: edit.field,
                // Editing a date or a section is expected and corrects OCR.
                // Editing a name or a student number means no document ever
                // proved that value, which is a different kind of fact.
                state: edit.isIdentity ? CheckState.failed : CheckState.notChecked,
                detail: edit.read == null
                    ? 'We read nothing. The applicant typed ${edit.submitted} themselves.'
                    : 'We read "${edit.read}". The applicant submitted "${edit.submitted}".',
                values: const [],
              ),
            ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.x1),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Corrections are normal on dates and sections. On a name or student '
                'number, the document never proved the value.',
                style: text.labelSmall?.copyWith(color: t.text.tertiary),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Queue pill ───────────────────────────────────────────────────────────────

/// The check summary as it appears in a queue row.
class ChecksPill extends StatelessWidget {
  const ChecksPill({super.key, required this.verdict, required this.summary});

  final String verdict;
  final String summary;

  @override
  Widget build(BuildContext context) {
    if (verdict == 'None') {
      return Text(
        summary,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: context.tokens.text.tertiary),
      );
    }

    return StatusPill(
      label: summary,
      dense: true,
      intent: switch (verdict) {
        'LookCloser' => StatusIntent.danger,
        'Unreadable' => StatusIntent.neutral,
        'Clear' => StatusIntent.success,
        _ => StatusIntent.neutral,
      },
    );
  }
}
