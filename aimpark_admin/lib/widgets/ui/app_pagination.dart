import 'package:flutter/material.dart';

import '../../theme/theme.dart';

/// One pager for the whole panel, replacing six private `_Pagination` and
/// `_PageBar` classes that each computed the page count slightly differently.
///
/// Page numbers are 1-based, matching the API.
class AppPagination extends StatelessWidget {
  const AppPagination({
    super.key,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.onPage,
    this.itemLabel = 'items',
  });

  /// Current page, 1-based.
  final int page;
  final int pageSize;

  /// Total matching records across all pages, as reported by the API.
  final int total;

  final ValueChanged<int> onPage;

  /// Plural noun for the summary line — "users", "payments", "violations".
  final String itemLabel;

  int get _totalPages => total <= 0 ? 1 : (total / pageSize).ceil();

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;

    final first = total == 0 ? 0 : (page - 1) * pageSize + 1;
    final last = total == 0 ? 0 : ((page - 1) * pageSize + pageSize).clamp(0, total);

    return Row(
      children: [
        Text(
          total == 0
              ? 'No $itemLabel'
              : 'Showing $first–$last of $total $itemLabel',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const Spacer(),
        Text(
          'Page $page of $_totalPages',
          style: text.bodySmall?.copyWith(color: t.text.secondary),
        ),
        const SizedBox(width: AppSpacing.x2),
        IconButton(
          icon: const Icon(Icons.chevron_left, size: AppSizes.iconMd),
          tooltip: 'Previous page',
          onPressed: page > 1 ? () => onPage(page - 1) : null,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right, size: AppSizes.iconMd),
          tooltip: 'Next page',
          onPressed: page < _totalPages ? () => onPage(page + 1) : null,
        ),
      ],
    );
  }
}
