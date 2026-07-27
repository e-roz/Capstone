import 'package:flutter/material.dart';

import '../core/utils/responsive.dart';

/// Title on the left, controls pushed to the right — the standard header for
/// every admin page.
///
/// A plain `Row` with a `Spacer` can't shrink, so on a phone the controls
/// overflow and Flutter paints the yellow/black stripes. Below the compact
/// breakpoint this switches to a `Wrap`, letting the controls fall onto a
/// second line instead.
class PageHeader extends StatelessWidget {
  const PageHeader({super.key, required this.title, this.actions = const []});

  final String title;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final titleWidget = Text(
      title,
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
    );

    if (context.isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          titleWidget,
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      );
    }

    return Row(
      children: [
        titleWidget,
        const Spacer(),
        for (final action in actions) ...[
          action,
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
