import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// A tab whose label carries how much work is waiting behind it.
///
/// The badge is hidden at zero rather than shown as "0": a queue that is
/// genuinely clear should look calm, and a row of noughts trains the eye to
/// stop reading the numbers at all.
class CountedTab extends StatelessWidget implements PreferredSizeWidget {
  const CountedTab({super.key, required this.label, required this.count});

  final String label;

  /// Null while the count is still loading, or if it failed — either way the
  /// tab renders as a plain label rather than guessing.
  final int? count;

  @override
  Size get preferredSize => const Size.fromHeight(46);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final waiting = count != null && count! > 0;

    return Tab(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (waiting) ...[
            const SizedBox(width: AppSpacing.x2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: t.status.danger.solid,
                borderRadius: AppRadii.fullAll,
              ),
              child: Text(
                '$count',
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: t.text.onDark),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
