import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// A table in a card, scrolling in both directions, with a footer slot for
/// pagination.
///
/// The nested `SingleChildScrollView`s are doing real work: a `DataTable` sizes
/// itself to its widest column, so on a narrow window it overflows horizontally
/// unless it can scroll, and a long result set overflows vertically unless it
/// can scroll independently of the page.
///
/// ```dart
/// AppDataTable(
///   columns: const [DataColumn(label: Text('Name')), DataColumn(label: Text('Status'))],
///   rows: [for (final u in users) DataRow(cells: [...], onSelectChanged: (_) => open(u))],
///   footer: AppPagination(page: page, total: total, pageSize: 25, onPage: setPage),
/// );
/// ```
class AppDataTable extends StatelessWidget {
  const AppDataTable({
    super.key,
    required this.columns,
    required this.rows,
    this.footer,
    this.minWidth,
    this.sortColumnIndex,
    this.sortAscending = true,
  });

  final List<DataColumn> columns;
  final List<DataRow> rows;

  /// Pagination or a summary line, pinned under the scrolling table.
  final Widget? footer;

  /// Forces the table at least this wide before horizontal scrolling kicks in.
  /// Without it a table with few short columns huddles on the left of a wide
  /// window instead of filling the card.
  final double? minWidth;

  final int? sortColumnIndex;
  final bool sortAscending;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return AppCardSurface(
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The table must be at least as wide as the space it was given,
                // or it sizes to its own content and leaves a wide window with
                // a narrow table hugging the left edge and a stripe of empty
                // card to the right. `minWidth` is a floor for *narrow* windows
                // — below it the table keeps its shape and scrolls sideways —
                // so the effective minimum is whichever is larger.
                final width = minWidth == null
                    ? constraints.maxWidth
                    : (minWidth! > constraints.maxWidth
                        ? minWidth!
                        : constraints.maxWidth);

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: width),
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: columns,
                        rows: rows,
                        sortColumnIndex: sortColumnIndex,
                        sortAscending: sortAscending,
                        showCheckboxColumn: false,
                        dividerThickness: 1,
                        border: TableBorder(
                          horizontalInside: BorderSide(color: t.border.subtle),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (footer != null) ...[
            Divider(height: 1, color: t.border.subtle),
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.x4, vertical: AppSpacing.x2),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

/// A bordered, rounded, clipped surface with no padding — the chrome an
/// [AppDataTable] needs, where [AppCard]'s inner padding would push the table's
/// own header row away from the card edge.
class AppCardSurface extends StatelessWidget {
  const AppCardSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: t.surface.card,
        borderRadius: AppRadii.lgAll,
        border: Border.all(color: t.border.normal),
        boxShadow: AppElevation.sm,
      ),
      child: child,
    );
  }
}

/// A right-aligned numeric cell with tabular figures, so a money or count
/// column stays in a straight line down the table.
class AppNumericCell extends StatelessWidget {
  const AppNumericCell(this.value, {super.key, this.emphasis = false});

  final String value;
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        value,
        style: AppTypography.tabular(
          (emphasis ? text.titleSmall : text.bodyMedium)!,
        ),
      ),
    );
  }
}

/// The small button that lives inside a table row.
///
/// It exists because a normal [OutlinedButton] carries Material's 40px minimum
/// height and cannot fit a 44px row, so four screens had each grown their own
/// private shrunken copy — with four different paddings and, in User
/// Management, four hardcoded `Colors.*` for the action tints.
///
/// [intent] tints border and label through the status tokens, so "Archive" is
/// the same red as a Rejected pill rather than a differently-chosen red.
class AppRowAction extends StatelessWidget {
  const AppRowAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.intent,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  /// Null leaves the button in the neutral outlined style.
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final colors = intent == null ? null : t.status.of(intent!);

    final style = OutlinedButton.styleFrom(
      foregroundColor: colors?.fg,
      side: colors == null ? null : BorderSide(color: colors.border),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
      minimumSize: const Size(0, AppSizes.controlHeightSm),
      textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    if (icon == null) {
      return OutlinedButton(style: style, onPressed: onPressed, child: Text(label));
    }

    return OutlinedButton.icon(
      icon: Icon(icon, size: AppSizes.iconSm),
      label: Text(label),
      style: style,
      onPressed: onPressed,
    );
  }
}

/// The two-line cell used wherever a table shows a name over an identifier.
class AppPrimaryCell extends StatelessWidget {
  const AppPrimaryCell({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(title, style: text.titleSmall),
        if (subtitle != null)
          Text(
            subtitle!,
            style: text.bodySmall?.copyWith(color: t.text.secondary),
          ),
      ],
    );
  }
}
