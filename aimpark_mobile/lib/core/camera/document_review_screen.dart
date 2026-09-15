import 'dart:io';

import 'package:flutter/material.dart';

import '../ocr/document_check.dart';
import '../ocr/document_scanner.dart';
import '../theme/theme.dart';
import '../widgets/widgets.dart';
import 'capture_spec.dart';

/// The moment right after a shutter press: the photo, full-screen, with a
/// real decision to make about it.
///
/// [DocumentPhotoPanel] shows this same photo again later, embedded in the
/// capture step — but by then the decision is already made. This screen is
/// the decision: a small thumbnail two inches wide, next to a "Continue"
/// button for the whole step, made "is this photo OK" easy to skim past. A
/// full screen and two buttons of equal weight does not.
///
/// Pops `true` for "use this photo". Anything else — the Retake button, or
/// the system back gesture — pops `false` or `null`, and the caller treats
/// both the same way: there is nothing else a photo someone backed away from
/// could mean.
class DocumentReviewScreen extends StatelessWidget {
  const DocumentReviewScreen({
    super.key,
    required this.photo,
    required this.spec,
    this.retakesSpent = false,
  });

  final CapturedDocument photo;
  final CaptureSpec spec;

  /// True once this document's retake allowance is spent — the photo will be
  /// sent as it is, so "Use this photo" is the only real choice even when the
  /// reading looks bad.
  final bool retakesSpent;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final issue = photo.issue;

    final intent = issue == null
        ? StatusIntent.success
        : retakesSpent
            ? StatusIntent.warning
            : StatusIntent.danger;
    final c = t.status.of(intent);

    final message = issue == null
        ? 'Looks good — we could read this one.'
        : retakesSpent
            ? '${documentIssueMessage(issue, spec.label)} We will send this '
                'photo as it is and have someone check it.'
            : documentIssueMessage(issue, spec.label);

    // No PopScope needed: the system back gesture pops with a null result,
    // which the caller already treats the same as an explicit Retake — there
    // is nothing else a photo someone backed away from could mean.
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: t.text.onDark,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: t.text.onDark),
        titleTextStyle:
            context.text.headlineSmall?.copyWith(color: t.text.onDark),
        title: Text(spec.label),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: InteractiveViewer(
                child: Center(
                  child: Image.file(File(photo.file.path)),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        issue == null
                            ? Icons.check_circle
                            : Icons.error_outline,
                        size: 18,
                        color: c.fg,
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      Expanded(
                        child: Text(
                          message,
                          style: context.text.bodyMedium
                              ?.copyWith(color: t.text.onDark),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          style: TextButton.styleFrom(
                            foregroundColor: t.text.onDark,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpacing.md,
                            ),
                            side: BorderSide(color: t.border.normal),
                          ),
                          child: const Text('Retake'),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: AppButton(
                          label: 'Use this photo',
                          onPressed: () => Navigator.of(context).pop(true),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
