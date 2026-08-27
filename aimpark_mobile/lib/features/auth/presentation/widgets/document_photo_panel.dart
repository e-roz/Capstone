import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../core/ocr/document_check.dart';
import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/theme/theme.dart';
import '../../data/models/document_spec.dart';

/// The capture target on a document step: an empty prompt before the photo is
/// taken, the photograph and a reading summary after.
///
/// Lifted out of `register_document_step_screen.dart`, which was doing this,
/// the four-document sequencing, the multipart upload and the retake routing
/// all in one 423-line file.
class DocumentPhotoPanel extends StatelessWidget {
  const DocumentPhotoPanel({
    super.key,
    required this.spec,
    required this.photo,
    required this.onCapture,
    this.retakesSpent = false,
  });

  final DocumentSpec spec;
  final CapturedDocument? photo;

  /// Null while the flow is submitting, so a retake cannot start mid-upload.
  final VoidCallback? onCapture;

  /// True once the retakes for this document are spent, so the photo will be
  /// sent as it is. Changes what an unusable photo is told: the problem stands,
  /// but it is no longer something the user is being asked to fix.
  final bool retakesSpent;

  static const double _height = 220;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    if (photo == null) {
      return InkWell(
        onTap: onCapture,
        borderRadius: AppRadius.mdAll,
        child: Container(
          height: _height,
          decoration: BoxDecoration(
            color: t.surface.card,
            borderRadius: AppRadius.mdAll,
            border: Border.all(color: t.border.normal, width: 1.5),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                size: 40,
                color: t.text.secondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Take a photo', style: context.text.labelLarge),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: Text(
                  spec.instruction,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final issue = photo!.issue;

    // A photo that cannot be used is an error while a retake would still help,
    // and a warning once it would not — at that point it is going up regardless
    // and the user has nothing left to do about it.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: AppRadius.mdAll,
          child: Image.file(
            File(photo!.file.path),
            height: _height,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              issue == null ? Icons.check_circle : Icons.error_outline,
              size: 18,
              color: c.fg,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(message, style: context.text.bodySmall),
            ),
            TextButton(onPressed: onCapture, child: const Text('Retake')),
          ],
        ),
      ],
    );
  }
}
