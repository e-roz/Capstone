import 'package:flutter/material.dart';

import '../models/registration_checks.dart';
import '../theme/theme.dart';
import 'ui/ui.dart';

/// The evidence on the registration review screen.
///
/// The API ran these checks at submission time and sends them already ordered,
/// most serious first. Nothing here re-sorts or recounts: the summary box, the
/// findings list and the queue's "top finding" all read the same list, so they
/// cannot disagree.
///
/// They report and never decide. A screen of passes means only that nothing
/// contradicted itself — whether the documents are genuine is a question no
/// rule in this system can answer.

// ── Severity → look ──────────────────────────────────────────────────────────

/// Grey for anything not checked, never green: a value the system could not
/// judge is the reason a human is looking at all.
StatusIntent intentOfSeverity(FindingSeverity severity) => switch (severity) {
      FindingSeverity.danger => StatusIntent.danger,
      FindingSeverity.warning => StatusIntent.warning,
      FindingSeverity.neutral => StatusIntent.neutral,
      FindingSeverity.passed => StatusIntent.success,
    };

IconData _iconOf(FindingSeverity severity) => switch (severity) {
      FindingSeverity.danger => Icons.close,
      FindingSeverity.warning => Icons.priority_high,
      FindingSeverity.neutral => Icons.info_outline,
      FindingSeverity.passed => Icons.check,
    };

String _categoryLabel(FindingCategory category) => switch (category) {
      FindingCategory.identity => 'Identity',
      FindingCategory.validity => 'Validity',
      FindingCategory.edited => 'Edited',
      FindingCategory.notChecked => 'Not checked',
      FindingCategory.passed => 'Passed',
    };

// ── Summary box ──────────────────────────────────────────────────────────────

/// "N things need a closer look". N is [RegistrationChecks.open] — exactly the
/// rows the findings list shows above its collapsed passes.
class FindingsSummaryBox extends StatelessWidget {
  const FindingsSummaryBox({super.key, required this.checks});

  final RegistrationChecks checks;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final open = checks.open;
    final n = open.length;

    final intent = checks.hasSerious
        ? StatusIntent.warning
        : n == 0
            ? StatusIntent.success
            : StatusIntent.neutral;
    final c = t.status.of(intent);

    final title = switch (n) {
      0 => 'Nothing needs a closer look',
      1 => '1 thing needs a closer look',
      _ => '$n things need a closer look',
    };

    // The same rows as the list below, counted by colour, so the header
    // already says how bad it is before anyone reads a finding.
    int count(FindingSeverity s) => open.where((f) => f.severity == s).length;
    final serious = count(FindingSeverity.danger);
    final warnings = count(FindingSeverity.warning);
    final toConfirm = count(FindingSeverity.neutral);
    final counts = [
      if (serious > 0)
        StatusPill(label: '$serious serious', intent: StatusIntent.danger, dense: true),
      if (warnings > 0)
        StatusPill(
            label: warnings == 1 ? '1 warning' : '$warnings warnings',
            intent: StatusIntent.warning,
            dense: true),
      if (toConfirm > 0)
        StatusPill(label: '$toConfirm to confirm', intent: StatusIntent.neutral, dense: true),
      if (checks.passed.isNotEmpty)
        StatusPill(
            label: '${checks.passed.length} passed',
            intent: StatusIntent.success,
            dense: true),
    ];

    final sentence = n == 0
        ? 'Every check passed and nothing was edited.'
        : checks.hasSerious
            ? 'Most serious first. Check each one against the documents.'
            : 'Nothing contradicted itself. These are left for you to confirm.';

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
            decoration: BoxDecoration(color: c.solid, borderRadius: AppRadii.mdAll),
            child: Icon(
              checks.hasSerious
                  ? Icons.priority_high
                  : n == 0
                      ? Icons.check
                      : Icons.info_outline,
              size: AppSizes.iconMd,
              color: t.text.onBrand,
            ),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.titleMedium?.copyWith(color: c.fg)),
                if (counts.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.x2),
                  Wrap(
                    spacing: AppSpacing.x2,
                    runSpacing: AppSpacing.x1,
                    children: counts,
                  ),
                ],
                const SizedBox(height: AppSpacing.x2),
                Text(sentence, style: text.bodyMedium?.copyWith(color: t.text.primary)),
                const SizedBox(height: AppSpacing.x2),
                Text(
                  'This is a summary, not a decision.',
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

// ── Findings list ────────────────────────────────────────────────────────────

/// "Findings, most serious first", with the passes folded into one row.
///
/// Tapping a finding that names a document opens that document's tab, so the
/// reviewer compares the claim with the evidence without hunting for it.
class FindingsCard extends StatefulWidget {
  const FindingsCard({super.key, required this.checks, this.onOpenDocument});

  final RegistrationChecks checks;
  final ValueChanged<String>? onOpenDocument;

  @override
  State<FindingsCard> createState() => _FindingsCardState();
}

class _FindingsCardState extends State<FindingsCard> {
  bool _showPassed = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final open = widget.checks.open;
    final passed = widget.checks.passed;

    final rows = <Widget>[
      for (final f in open) _row(f),
      if (passed.isNotEmpty) ...[
        InkWell(
          onTap: () => setState(() => _showPassed = !_showPassed),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.cardPadding,
              vertical: AppSpacing.x3,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: AppSizes.iconMd,
                  color: t.status.success.fg,
                ),
                const SizedBox(width: AppSpacing.x3),
                Expanded(
                  child: Text(
                    '${passed.length} passed',
                    style: text.titleSmall?.copyWith(color: t.status.success.fg),
                  ),
                ),
                Text(
                  _showPassed ? 'Hide' : 'Show',
                  style: text.bodyMedium?.copyWith(color: t.text.secondary),
                ),
                Icon(
                  _showPassed ? Icons.expand_less : Icons.expand_more,
                  size: AppSizes.iconMd,
                  color: t.text.secondary,
                ),
              ],
            ),
          ),
        ),
        if (_showPassed)
          for (final f in passed) _row(f),
      ],
    ];

    return AppSectionCard(
      title: 'Findings, most serious first',
      icon: Icons.rule,
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, row) in rows.indexed)
            DecoratedBox(
              decoration: BoxDecoration(
                border: i == 0
                    ? null
                    : Border(top: BorderSide(color: t.border.subtle)),
              ),
              child: row,
            ),
        ],
      ),
    );
  }

  Widget _row(Finding f) {
    final open = widget.onOpenDocument;
    final row = FindingRow(finding: f);
    if (open == null || f.document == null) return row;
    return InkWell(onTap: () => open(f.document!), child: row);
  }
}

/// Icon, category tag, bold title, one line of detail.
class FindingRow extends StatelessWidget {
  const FindingRow({super.key, required this.finding});

  final Finding finding;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final c = t.status.of(intentOfSeverity(finding.severity));

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.cardPadding,
        vertical: AppSpacing.x3,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AppSizes.iconMd,
            height: AppSizes.iconMd,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: c.bg,
              shape: BoxShape.circle,
              border: Border.all(color: c.border),
            ),
            child: Icon(_iconOf(finding.severity), size: 12, color: c.fg),
          ),
          const SizedBox(width: AppSpacing.x3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: AppSpacing.x2,
                  runSpacing: AppSpacing.x1,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    StatusPill(
                      label: _categoryLabel(finding.category),
                      intent: StatusIntent.neutral,
                      dense: true,
                      showDot: false,
                    ),
                    Text(finding.title, style: text.titleSmall),
                  ],
                ),
                if (finding.detail case final detail?)
                  Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.labelGap),
                    child: Text(
                      detail,
                      style: text.bodyMedium?.copyWith(color: t.text.secondary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Queue cell ───────────────────────────────────────────────────────────────

/// The most serious finding in words, plus how many more, for a queue row.
class TopFindingCell extends StatelessWidget {
  const TopFindingCell({
    super.key,
    required this.verdict,
    required this.summary,
    required this.topFinding,
    required this.severity,
    required this.count,
  });

  final String verdict;

  /// Shown only when nothing was submitted ("No documents submitted").
  final String summary;
  final String? topFinding;
  final FindingSeverity? severity;
  final int count;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    if (verdict == 'None') {
      return Text(summary, style: text.bodySmall?.copyWith(color: t.text.tertiary));
    }

    if (topFinding == null) {
      return const StatusPill(
        label: 'Nothing flagged',
        intent: StatusIntent.neutral,
        dense: true,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        StatusPill(
          label: topFinding!,
          intent: intentOfSeverity(severity ?? FindingSeverity.neutral),
          dense: true,
        ),
        if (count > 1) ...[
          const SizedBox(width: AppSpacing.x2),
          Text(
            '+${count - 1} more',
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
        ],
      ],
    );
  }
}
