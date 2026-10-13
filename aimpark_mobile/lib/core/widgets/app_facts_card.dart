import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

/// One recorded fact: what it is, and what it says.
class AppFact {
  const AppFact(
    this.label,
    this.value, {
    this.intent,
    this.struck = false,
    this.note,
  });

  final String label;

  /// Empty renders as an em dash rather than as blank space, so a missing
  /// value reads as "we have nothing" instead of as a layout bug.
  final String value;

  /// Colours the value where it carries a verdict of its own — an overdue
  /// date, a waived charge.
  final StatusIntent? intent;

  /// Draws the value with a line through it: a figure that is on the record but
  /// does not apply — a penalty on a violation whose appeal was accepted. Left
  /// printed at full weight, it contradicted the banner above it that said no
  /// penalty applied.
  final bool struck;

  /// A short line under the value, for saying why: "Not charged".
  final String? note;
}

/// A card of label/value pairs, divided by hairlines, with an optional
/// emphasised row at the bottom for the figure the card is really about.
///
/// This is the shape every detail screen in the app was building by hand out of
/// an [AppCard] and a column of `AppDetailRow`s — undivided, so eight facts ran
/// together into a wall of text, and with the amount rendered at the same size
/// as the slot code beside it.
///
/// Facts are listed in the order a person would check them, which is why the
/// caller passes an ordered list rather than a map.
class AppFactsCard extends StatelessWidget {
  const AppFactsCard({
    super.key,
    required this.facts,
    this.title,
    this.total,
  });

  /// An eyebrow above the first row — "Recorded facts", "How this was
  /// calculated". Omit it where the card's contents are self-evident.
  final String? title;

  final List<AppFact> facts;

  /// Set apart by a stronger divider and rendered at heading size. For the one
  /// number the screen exists to communicate: a penalty, an amount due.
  final AppFact? total;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(0, AppSpacing.sm + 6, 0, 10),
              child: Text(title!.toUpperCase(), style: context.text.labelSmall),
            ),
          for (var i = 0; i < facts.length; i++)
            _Row(
              fact: facts[i],
              // The first row only needs a line above it when a title is
              // sitting there to be separated from.
              divided: i > 0 || title != null,
            ),
          if (total != null) _Row(fact: total!, divided: true, emphasis: true),
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.fact,
    required this.divided,
    this.emphasis = false,
  });

  final AppFact fact;
  final bool divided;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = fact.intent == null ? null : t.status.of(fact.intent!);

    return Container(
      padding: EdgeInsets.symmetric(vertical: emphasis ? AppSpacing.sm + 6 : 11),
      decoration: divided
          ? BoxDecoration(
              border: Border(
                top: BorderSide(
                  // The total's rule is the full border tone rather than the
                  // subtle one, so the sum reads as separated from the things
                  // being summed.
                  color: emphasis ? t.border.normal : t.border.subtle,
                ),
              ),
            )
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // A plain Text, deliberately not Flexible. A Flexible label beside an
          // Expanded value splits the free width between them *evenly* and leaves
          // the label's unused share empty, so the values stopped short of the
          // right edge and ended wherever the label's half ran out. The value
          // shrinks to fit instead — see the FittedBox below.
          Text(
            fact.label,
            style: emphasis
                ? context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w700)
                : context.text.bodySmall,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Scaled down to fit rather than wrapped: a figure split over two
                // lines is not a figure.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    fact.value.isEmpty ? '—' : fact.value,
                    textAlign: TextAlign.end,
                    // Tabular throughout: these columns are read down as much as
                    // across, and proportional digits make a column of times and
                    // amounts look ragged.
                    style: AppTypography.tabular(
                      (emphasis
                          ? context.text.headlineMedium
                          : context.text.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ))!,
                    ).copyWith(
                      color: fact.struck ? t.text.secondary : c?.fg,
                      decoration:
                          fact.struck ? TextDecoration.lineThrough : null,
                    ),
                  ),
                ),
                if (fact.note != null)
                  Text(
                    fact.note!,
                    textAlign: TextAlign.end,
                    style: context.text.bodySmall?.copyWith(
                      color: c?.fg,
                      fontWeight: FontWeight.w700,
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
