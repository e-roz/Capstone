import 'package:flutter/material.dart';

import '../theme/theme.dart';

/// An inline message attached to the thing it is about.
///
/// Distinct from `showAppMessage`, which is transient and floats over the whole
/// screen. A notice stays put, so it is the right shape for something the user
/// has to act on before moving on: a document sent back for a retake, a plate
/// reading that disagrees with the receipt.
///
/// Three screens each built this out of a `Container` with a tinted
/// `BoxDecoration`, a hardcoded icon and a hardcoded radius. Two of them used
/// an 8px corner where the rest of the app uses 12.
class AppNotice extends StatelessWidget {
  const AppNotice({
    super.key,
    required this.message,
    this.intent = StatusIntent.info,
    this.icon,
    this.title,
    this.action,
  });

  final String message;

  /// What kind of message this is. Drives the tint, the border and the default
  /// icon together, so they cannot disagree.
  final StatusIntent intent;

  /// Overrides the intent's default icon.
  final IconData? icon;

  /// An optional bold line above [message].
  final String? title;

  /// A button under the message — "Retake the plate photo", "Try again".
  final Widget? action;

  IconData get _icon =>
      icon ??
      switch (intent) {
        StatusIntent.success => Icons.check_circle_outline_rounded,
        StatusIntent.warning => Icons.warning_amber_rounded,
        StatusIntent.danger => Icons.error_outline_rounded,
        StatusIntent.info || StatusIntent.brand => Icons.info_outline_rounded,
        StatusIntent.neutral => Icons.help_outline_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final c = context.tokens.status.of(intent);

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: c.bg,
        borderRadius: AppRadius.smAll,
        border: Border.all(color: c.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: AppSizes.iconMd, color: c.fg),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null) ...[
                  Text(
                    title!,
                    style: context.text.labelLarge?.copyWith(color: c.fg),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  message,
                  style: context.text.bodySmall?.copyWith(color: c.fg),
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Align(alignment: Alignment.centerLeft, child: action!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
