import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/responsive.dart';
import '../models/investigation.dart';
import '../providers/investigation_provider.dart';
import '../theme/theme.dart';
import 'investigation_panel.dart';

/// The Overview's search box: a name, plate, card or student number in, a
/// grouped pick-list out. Choosing a result opens its investigation panel.
///
/// It waits for a pause in typing before asking, and does not ask at all for
/// fewer than two characters (one letter matches half the school).
class OverviewSearch extends ConsumerStatefulWidget {
  const OverviewSearch({super.key, this.width = 320});

  final double width;

  @override
  ConsumerState<OverviewSearch> createState() => _OverviewSearchState();
}

class _OverviewSearchState extends ConsumerState<OverviewSearch> {
  static const _pause = Duration(milliseconds: 300);
  static const _minLength = 2;

  final _controller = TextEditingController();
  final _focus = FocusNode();

  /// The kinds in the order the pick-list groups them, with their headings.
  static const _groups = [
    ('person', 'People'),
    ('visitor', 'Visitors'),
    ('card', 'Cards nobody holds'),
    ('plate', 'Unregistered plates'),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<Iterable<SearchResult>> _options(TextEditingValue value) async {
    final typed = value.text.trim();
    if (typed.length < _minLength) return const [];

    await Future<void>.delayed(_pause);
    // Typing went on during the pause: that newer text will ask for itself.
    if (!mounted || _controller.text.trim() != typed) return const [];

    final List<SearchResult> found;
    try {
      found = await ref.read(overviewSearchProvider(typed).future);
    } catch (_) {
      return const [];
    }

    return [
      for (final (kind, _) in _groups) ...found.where((r) => r.kind == kind),
    ];
  }

  void _choose(SearchResult result) {
    _controller.clear();
    _focus.unfocus();
    showInvestigationPanel(
      context,
      subject: result.subject,
      title: result.title,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return SizedBox(
      width: context.isCompact ? double.infinity : widget.width,
      height: AppSizes.controlHeight,
      child: RawAutocomplete<SearchResult>(
        textEditingController: _controller,
        focusNode: _focus,
        optionsBuilder: _options,
        displayStringForOption: (r) => r.title,
        onSelected: _choose,
        fieldViewBuilder: (context, controller, focusNode, _) => TextField(
          controller: controller,
          focusNode: focusNode,
          style: Theme.of(context).textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search a name, plate or card',
            prefixIcon: const Icon(Icons.search, size: AppSizes.iconMd),
            suffixIcon: ValueListenableBuilder(
              valueListenable: controller,
              builder: (_, value, _) => value.text.isEmpty
                  ? const SizedBox.shrink()
                  : IconButton(
                      icon: const Icon(Icons.close, size: AppSizes.iconSm),
                      tooltip: 'Clear',
                      onPressed: controller.clear,
                    ),
            ),
          ),
        ),
        optionsViewBuilder: (context, onSelected, options) {
          final list = options.toList();
          final text = Theme.of(context).textTheme;

          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 8,
              color: t.surface.card,
              borderRadius: AppRadii.smAll,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: context.isCompact ? 360 : 420,
                  maxHeight: 360,
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.x1),
                  shrinkWrap: true,
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final r = list[i];
                    final first = i == 0 || list[i - 1].kind != r.kind;
                    final heading =
                        _groups.firstWhere((g) => g.$1 == r.kind).$2;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (first)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                AppSpacing.x3, AppSpacing.x2, AppSpacing.x3, 2),
                            child: Text(
                              heading.toUpperCase(),
                              style: text.labelSmall?.copyWith(
                                color: t.text.tertiary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: () => onSelected(r),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.x3,
                                vertical: AppSpacing.x2),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.title, style: text.bodyMedium),
                                if (r.subtitle.isNotEmpty)
                                  Text(
                                    r.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: text.bodySmall
                                        ?.copyWith(color: t.text.secondary),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
