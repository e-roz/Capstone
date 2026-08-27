import 'package:flutter/material.dart';

import '../theme/theme.dart';
import 'app_card.dart';

/// The row that every list in this app is built from.
///
/// It replaces eight private classes that were all the same shape — a leading
/// icon chip, a bold title, a muted second line, something on the right, and a
/// chevron if you could tap it:
///
/// `_ActivityTile` (home), `_PaymentTile`, `_HistoryTile`, `_ViolationTile`,
/// `_IncidentTile`, `_NotificationTile`, `_MenuTile` (account) and the trailing
/// half of `_SlotTile`. Each had drifted: three different gaps between the icon
/// and the text, two different icon chip sizes, and a chevron that appeared on
/// some tappable rows and not others.
///
/// ```dart
/// AppListRow(
///   icon: Icons.local_parking_rounded,
///   title: log.slotCode ?? 'Unassigned slot',
///   subtitle: Formatters.sessionRange(log.entryTime, log.exitTime, log.duration),
///   trailing: const AppStatusBadge(label: 'Parked now', intent: StatusIntent.success),
/// )
/// ```
class AppListRow extends StatelessWidget {
  const AppListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.note,
    this.icon,
    this.leading,
    this.trailing,
    this.onTap,
    this.intent,
    this.tone,
    this.showChevron = true,
    this.dense = false,
  }) : assert(icon == null || leading == null,
            'Give AppListRow an icon or a leading widget, not both');

  /// The line you read first.
  final String title;

  /// The muted line under it — a date, a duration, a category.
  final String? subtitle;

  /// A third line for something that needs its own emphasis, such as a payment
  /// due date that turns red once it is overdue.
  final Widget? note;

  /// Rendered inside a rounded chip. The common case.
  final IconData? icon;

  /// For rows whose leading slot is not an icon — an avatar, a thumbnail.
  final Widget? leading;

  /// A badge, an amount, a switch. Sits left of the chevron.
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Colours the icon chip by meaning. Left null the chip is a neutral well,
  /// which is right for most rows: a list where every row shouts is a list
  /// where nothing does.
  final StatusIntent? intent;

  /// Colours the *title and icon directly*, for a row that is itself an action
  /// with weight — "Log Out" in red. Distinct from [intent], which tints a
  /// chip behind a neutral icon. When set, the chevron is dropped: a
  /// destructive action is a button, not a way further in.
  final Color? tone;

  /// Suppress on a row that opens nothing, so the chevron never promises a
  /// destination that does not exist.
  final bool showChevron;

  /// Tighter vertical padding, for a long list of short rows.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = intent == null ? null : t.status.of(intent!);
    final tappable = onTap != null;

    return AppCard(
      onTap: onTap,
      padding: EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: dense ? AppSpacing.sm : AppSpacing.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: AppSpacing.sm),
          ] else if (icon != null) ...[
            _IconChip(icon: icon!, background: c?.bg, foreground: tone ?? c?.fg),
            const SizedBox(width: AppSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: context.text.labelLarge?.copyWith(color: tone),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (note != null) ...[
                  const SizedBox(height: 2),
                  note!,
                ],
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
          // Only where tapping actually goes somewhere. `tone` marks a row that
          // performs an action in place rather than navigating.
          if (tappable && showChevron && tone == null)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.xs),
              child: Icon(
                Icons.chevron_right_rounded,
                color: t.text.secondary,
                size: AppSizes.iconLg,
              ),
            ),
        ],
      ),
    );
  }
}

/// The rounded well behind a row's leading icon. Also used on its own by the
/// detail screens, which show the same chip above a heading.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.background, this.foreground});

  final IconData icon;
  final Color? background;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: AppSizes.rowIcon,
      height: AppSizes.rowIcon,
      decoration: BoxDecoration(
        color: background ?? t.surface.muted,
        borderRadius: AppRadius.smAll,
      ),
      child: Icon(
        icon,
        color: foreground ?? t.text.secondary,
        size: AppSizes.iconMd,
      ),
    );
  }
}

/// Vertical spacing between consecutive [AppListRow]s.
///
/// A widget rather than a bare `SizedBox` so the gap is named at the call site
/// and cannot quietly become 12 on one screen and 8 on the next.
class AppRowGap extends StatelessWidget {
  const AppRowGap({super.key});

  @override
  Widget build(BuildContext context) =>
      const SizedBox(height: AppSpacing.gutter);
}

/// A read-only label and value on one line, label left and value right.
///
/// Replaces the two `_InfoRow` classes on the payment and violation detail
/// screens — byte-identical copies that had already drifted to different top
/// padding.
///
/// A long value wraps rather than overflowing: "Temporary suspension · 14
/// day(s)" was pushing the overflow stripes off the right edge on a 360dp
/// screen.
class AppDetailRow extends StatelessWidget {
  const AppDetailRow({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.intent,
  }) : assert(value != null || child != null,
            'AppDetailRow needs either a value or a child');

  final String label;
  final String? value;
  final Widget? child;

  /// Colours the value where it carries a verdict of its own — an overdue
  /// date, a suspension.
  final StatusIntent? intent;

  @override
  Widget build(BuildContext context) {
    final c = intent == null ? null : context.tokens.status.of(intent!);

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: context.text.bodySmall),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: child ??
                Text(
                  value!.isEmpty ? '—' : value!,
                  textAlign: TextAlign.end,
                  style: context.text.labelLarge?.copyWith(color: c?.fg),
                ),
          ),
        ],
      ),
    );
  }
}

/// A read-only label and value, stacked.
///
/// For detail cards laid out as a grid of fields rather than as a list of
/// rows — where the label sits above its value and several fit across a line.
class AppInfoRow extends StatelessWidget {
  const AppInfoRow({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.emphasis = false,
  }) : assert(value != null || child != null,
            'AppInfoRow needs either a value or a child');

  final String label;

  /// Plain text. Use [child] when the value is a badge, a link, or anything
  /// that is not a string.
  final String? value;

  final Widget? child;

  /// Renders the value at heading weight — for the one field on a card that
  /// matters most, such as an amount due or a plate number.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: context.text.labelSmall),
        const SizedBox(height: AppSpacing.labelGap),
        child ??
            Text(
              value!.isEmpty ? '—' : value!,
              style: emphasis
                  ? context.text.headlineSmall
                  : context.text.bodyMedium,
            ),
      ],
    );
  }
}
