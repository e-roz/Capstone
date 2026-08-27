import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'app_button.dart';

/// Success moment shown after a rewarding action (e.g. finishing
/// registration). Replaces a plain snackbar with a bouncy, celebratory beat —
/// the highest-payoff spot for the gamified feel since it's the "you did it"
/// moment.
class CelebrationDialog extends StatelessWidget {
  const CelebrationDialog({
    super.key,
    required this.title,
    required this.message,
    this.buttonLabel = 'Continue',
  });

  final String title;
  final String message;
  final String buttonLabel;

  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    String buttonLabel = 'Continue',
  }) {
    // The haptic lands with the dialog rather than with the tap that caused
    // it, so the celebration is felt at the moment it is seen.
    HapticFeedback.mediumImpact();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => CelebrationDialog(
        title: title,
        message: message,
        buttonLabel: buttonLabel,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = t.status.success;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
          color: t.surface.overlay,
          borderRadius: AppRadius.lgAll,
          border: Border.all(color: t.border.normal, width: 1.5),
          boxShadow: AppElevation.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.4, end: 1.0),
              duration: const Duration(milliseconds: 450),
              curve: AppMotion.bouncy,
              builder: (context, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(color: c.bg, shape: BoxShape.circle),
                child: Icon(
                  Icons.check_rounded,
                  color: c.solid,
                  size: AppSizes.iconHero,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              style: context.text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              style: context.text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                label: buttonLabel,
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks before something that cannot be undone.
///
/// Three screens each built this `AlertDialog` by hand — logging out, deleting
/// an incident report, discarding an edit — and each styled its destructive
/// action differently: one red `TextButton`, one plain one, one that put the
/// destructive choice on the left where Cancel usually sits.
///
/// Returns true only if the user confirmed.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool destructive = true,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final t = ctx.tokens;
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(cancelLabel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              foregroundColor:
                  destructive ? t.status.danger.fg : t.brand.subtleText,
            ),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );

  return result ?? false;
}
