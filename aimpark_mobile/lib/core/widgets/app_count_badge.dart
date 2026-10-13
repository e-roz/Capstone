import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// The small red count that sits on a corner of an icon — unread alerts on the
/// bell, on a nav tab.
///
/// One widget because the nav and the bell had each drawn their own, and the
/// nav's was set in 8px type. A count is a number someone has to read at a
/// glance, so it is 11px bold digits — the one place the app sets text below
/// its 12px floor, because there is no room for more and a digit needs far less
/// than a word.
///
/// Anything over 99 renders as "99+" so the pill cannot grow wide enough to
/// break the row it sits in.
class AppCountBadge extends StatelessWidget {
  const AppCountBadge({super.key, required this.count, this.ringColor});

  final int count;

  /// The surface the badge overlaps. A ring in that colour keeps the badge
  /// legible where it crosses an icon, and invisible against the surface itself.
  /// Defaults to the card colour, which is what the nav bar and the header sit on
  /// or near.
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    final t = context.tokens;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: t.status.danger.solid,
        borderRadius: AppRadius.fullAll,
        border: Border.all(color: ringColor ?? t.surface.card, width: 1.5),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        textAlign: TextAlign.center,
        style: context.text.labelSmall?.copyWith(
          color: t.text.onDark,
          fontSize: 11,
          height: 1.2,
          letterSpacing: 0,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
