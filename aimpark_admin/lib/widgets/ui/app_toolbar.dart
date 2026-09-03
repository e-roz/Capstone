import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/utils/responsive.dart';
import '../../theme/theme.dart';

/// The control strip between a page header and its table: search on the left,
/// filters beside it, actions pinned right.
///
/// Filters used to live in [AppPageHeader]'s `actions` slot, which put a
/// dropdown labelled "All Status" at the same visual weight as a primary button
/// and left the eye no way to tell "this narrows the table" from "this does
/// something". Separating the two rows is most of what makes a table screen
/// read as a workspace rather than a form.
///
/// ```dart
/// AppToolbar(
///   search: AppSearchField(onChanged: notifier.setSearch),
///   filters: [AppFilterDropdown(label: 'Status', value: q.status, ...)],
///   trailing: [IconButton(icon: Icon(Icons.refresh), onPressed: refresh)],
/// );
/// ```
class AppToolbar extends StatelessWidget {
  const AppToolbar({
    super.key,
    this.search,
    this.filters = const [],
    this.trailing = const [],
  });

  /// Usually an [AppSearchField]. Omit it when the screen's data source has no
  /// search — a box that silently searches only the page you can already see is
  /// worse than no box at all.
  ///
  /// Rendered at the **right** of the strip, not the left. On the left it sat
  /// directly under the sidebar and read as part of the navigation rather than
  /// as a control on the table; filters belong on the left because they change
  /// what the table contains, and search sits with the other actions.
  final Widget? search;

  /// Controls that narrow the table. Usually [AppFilterDropdown]s.
  final List<Widget> filters;

  /// Actions that act on the table rather than filter it — refresh, export.
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    if (search == null && filters.isEmpty && trailing.isEmpty) {
      return const SizedBox.shrink();
    }

    // Below the compact breakpoint a single row cannot hold a search box and
    // two filters, so the strip stacks instead of clipping.
    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?search,
          if (filters.isNotEmpty || trailing.isNotEmpty) ...[
            if (search != null) const SizedBox(height: AppSpacing.x2),
            Wrap(
              spacing: AppSpacing.controlGap,
              runSpacing: AppSpacing.controlGap,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [...filters, ...trailing],
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        for (final widget in filters) ...[
          widget,
          const SizedBox(width: AppSpacing.controlGap),
        ],
        const Spacer(),
        if (search case final field?) ...[
          const SizedBox(width: AppSpacing.controlGap),
          field,
        ],
        for (final widget in trailing) ...[
          const SizedBox(width: AppSpacing.controlGap),
          widget,
        ],
      ],
    );
  }
}

/// A debounced search box sized for a toolbar.
///
/// The debounce is the point: without it every keystroke fires a request, and
/// the results visibly race each other on a slow connection.
class AppSearchField extends StatefulWidget {
  const AppSearchField({
    super.key,
    required this.onChanged,
    this.hint = 'Search',
    this.initialValue,
    this.debounce = const Duration(milliseconds: 400),
    this.width = 280,
  });

  /// Called with the trimmed query once the user stops typing.
  final ValueChanged<String> onChanged;

  final String hint;
  final String? initialValue;
  final Duration debounce;
  final double width;

  @override
  State<AppSearchField> createState() => _AppSearchFieldState();
}

class _AppSearchFieldState extends State<AppSearchField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {}); // Toggles the clear button.
    _debounce?.cancel();
    _debounce = Timer(widget.debounce, () => widget.onChanged(value.trim()));
  }

  void _clear() {
    _debounce?.cancel();
    _controller.clear();
    setState(() {});
    widget.onChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      width: context.isCompact ? double.infinity : widget.width,
      height: AppSizes.controlHeight,
      child: TextField(
        controller: _controller,
        onChanged: _onChanged,
        style: Theme.of(context).textTheme.bodyMedium,
        decoration: InputDecoration(
          hintText: widget.hint,
          // Magnifier on the trailing edge, swapped out for the clear button
          // once there is something to clear — the two never need to show at
          // once, and sharing the slot keeps the text starting in the same
          // place whether the box is empty or not.
          suffixIcon: _controller.text.isEmpty
              ? Icon(Icons.search,
                  size: AppSizes.iconMd, color: t.text.tertiary)
              : IconButton(
                  icon: const Icon(Icons.close, size: AppSizes.iconSm),
                  tooltip: 'Clear search',
                  onPressed: _clear,
                ),
          suffixIconConstraints: const BoxConstraints(
              minWidth: AppSizes.controlHeight, minHeight: 0),
          contentPadding: const EdgeInsets.only(left: AppSpacing.x3),
        ),
      ),
    );
  }
}

/// One choice in an [AppFilterDropdown].
@immutable
class AppFilterOption<T> {
  const AppFilterOption(this.value, this.label);

  final T value;
  final String label;
}

/// A menu value that is never null, so the "all" entry can actually be picked.
///
/// `PopupMenuButton` cannot tell a null selection from a dismissed menu: it
/// calls `onCanceled` for both. The "all" entry's value is null by definition,
/// so it silently did nothing — you could filter down but never back out, on
/// every filter in the panel. Boxing the value keeps the menu's own type
/// non-nullable and leaves null free to go on meaning "dismissed".
@immutable
class _FilterChoice<T> {
  const _FilterChoice(this.value);

  final T? value;
}

/// A filter rendered as a pill rather than a bare `DropdownButton`.
///
/// It shows its own name even when nothing is chosen ("Status: All"), so the
/// toolbar still says what can be filtered on. And it tints itself when a value
/// is set, which is the only cheap way to answer "why is this table empty?" —
/// the answer is almost always a filter someone forgot they left on.
class AppFilterDropdown<T> extends StatefulWidget {
  const AppFilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
    this.allLabel = 'All',
    this.allowAll = true,
  });

  /// The filter's name — "Status", "Action".
  final String label;

  /// Current selection. Null means unfiltered.
  final T? value;

  final List<AppFilterOption<T>> options;

  /// Called with null when the user picks the "all" entry.
  final ValueChanged<T?> onChanged;

  final String allLabel;

  /// Whether to offer the "no filter" entry at all.
  ///
  /// False for a filter that always holds a value. A report period is always
  /// *some* period, so an "all" row there both duplicates a real option and
  /// offers a state the screen cannot be in.
  final bool allowAll;

  @override
  State<AppFilterDropdown<T>> createState() => _AppFilterDropdownState<T>();
}

class _AppFilterDropdownState<T> extends State<AppFilterDropdown<T>> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final text = Theme.of(context).textTheme;
    final active = widget.value != null;

    final selected = widget.options
        .where((o) => o.value == widget.value)
        .map((o) => o.label)
        .firstOrNull;

    return PopupMenuButton<_FilterChoice<T>>(
      tooltip: 'Filter by ${widget.label.toLowerCase()}',
      onSelected: (choice) => widget.onChanged(choice.value),
      itemBuilder: (context) => [
        if (widget.allowAll)
          PopupMenuItem<_FilterChoice<T>>(
            value: _FilterChoice<T>(null),
            child: _MenuRow(label: widget.allLabel, checked: !active),
          ),
        for (final option in widget.options)
          PopupMenuItem<_FilterChoice<T>>(
            value: _FilterChoice<T>(option.value),
            child: _MenuRow(
              label: option.label,
              checked: option.value == widget.value,
            ),
          ),
      ],
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: AppMotion.fast,
          curve: AppMotion.standard,
          height: AppSizes.controlHeight,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.x3),
          decoration: BoxDecoration(
            color: active
                ? t.brand.subtle
                : _hovered
                    ? t.surface.hover
                    : t.surface.card,
            borderRadius: AppRadii.mdAll,
            border: Border.all(
              color: active
                  ? t.brand.primary
                  : _hovered
                      ? t.border.strong
                      : t.border.normal,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${widget.label}: ',
                style: text.bodyMedium?.copyWith(color: t.text.secondary),
              ),
              Text(
                selected ?? widget.allLabel,
                style: text.bodyMedium?.copyWith(
                  color: active ? t.brand.subtleText : t.text.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: AppSpacing.x1),
              Icon(
                Icons.expand_more,
                size: AppSizes.iconSm,
                color: active ? t.brand.subtleText : t.text.secondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A menu entry with room reserved for the check mark, so the labels stay in a
/// straight line whether or not one of them is ticked.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.label, required this.checked});

  final String label;
  final bool checked;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      children: [
        SizedBox(
          width: AppSpacing.x5,
          child: checked
              ? Icon(Icons.check, size: AppSizes.iconSm, color: t.brand.primary)
              : null,
        ),
        Text(label),
      ],
    );
  }
}
