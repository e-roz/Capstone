import 'package:flutter/material.dart';

import '../theme/theme.dart';
import '../widgets/widgets.dart';

/// The three things that make a document photo usable, shown once before the
/// first capture of a session.
///
/// Not per-document: the same three things — use the real thing, keep it
/// lit, keep it whole in frame — are what every one of these photos needs,
/// and asking again before the second and third document would be friction
/// with nothing new to say. [CaptureTipsPreference] decides whether this has
/// already been shown; this widget only draws it.
class CaptureTipsSheet extends StatelessWidget {
  const CaptureTipsSheet({super.key});

  static const _tips = [
    (
      icon: Icons.badge_outlined,
      text: 'Use the physical document — not a photo of a photo, or a copy '
          'on a screen.',
    ),
    (
      icon: Icons.wb_sunny_outlined,
      text: 'Avoid blur or glare. Hold steady, and keep it out of direct '
          'light.',
    ),
    (
      icon: Icons.crop_free_rounded,
      text: 'Keep the whole document inside the frame — nothing cut off at '
          'the edges.',
    ),
  ];

  /// Shows the sheet, and resolves true once the user taps through.
  ///
  /// Resolves false (or null) if they dismiss it instead — the caller treats
  /// that as "not now" rather than "never", so the camera simply does not
  /// open this time.
  static Future<bool> show(BuildContext context) async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CaptureTipsSheet(),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Before you scan', style: context.text.headlineMedium),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'A few things that make the difference between a clean read '
              'and a retake.',
              style: context.text.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.lg),
            for (final tip in _tips) ...[
              _TipRow(icon: tip.icon, text: tip.text),
              const SizedBox(height: AppSpacing.md),
            ],
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Start scanning',
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}

class _TipRow extends StatelessWidget {
  const _TipRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.brand.subtle,
            borderRadius: AppRadius.mdAll,
          ),
          child: Icon(icon, color: t.brand.primary, size: AppSizes.iconMd),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(text, style: context.text.bodyMedium),
          ),
        ),
      ],
    );
  }
}
