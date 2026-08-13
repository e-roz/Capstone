import 'package:flutter/material.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/scan_result.dart';
import '../screens/document_capture_screen.dart';

/// One document's row on the upload step: its state, its photo, and anything
/// the server said about it.
class DocumentCaptureTile extends StatelessWidget {
  const DocumentCaptureTile({
    super.key,
    required this.spec,
    required this.captured,
    required this.diagnosis,
    required this.onCapture,
  });

  final DocumentSpec spec;
  final CapturedDocument? captured;

  /// Set when the last scan could not read this document.
  final DocumentDiagnosis? diagnosis;

  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    final photo = captured;
    final failed = diagnosis != null;

    return InkWell(
      onTap: onCapture,
      borderRadius: BorderRadius.circular(AppRadius.sm),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: BorderRadius.circular(AppRadius.sm),
          border: Border.all(
            color: failed
                ? AppColors.errorDefault
                : photo != null
                ? AppColors.successDefault
                : AppColors.borderDefault,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _Thumbnail(photo: photo),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(spec.label, style: AppTextStyles.labelBold),
                      const SizedBox(height: 2),
                      Text(
                        photo == null ? spec.instruction : 'Tap to retake',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ),
                Icon(
                  photo == null
                      ? Icons.camera_alt_outlined
                      : failed
                      ? Icons.error_outline
                      : Icons.check_circle,
                  color: photo == null
                      ? AppColors.textSecondary
                      : failed
                      ? AppColors.errorDefault
                      : AppColors.successDefault,
                ),
              ],
            ),
            if (photo != null && photo.payload == null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  "Your phone couldn't read this one. You can still submit it — "
                  "you'll just type the details yourself.",
                  style: AppTextStyles.bodySmall,
                ),
              ),
            if (diagnosis != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  diagnosis!.message,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.errorDefault,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.photo});

  final CapturedDocument? photo;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppSpacing.sm),
      child: SizedBox(
        width: 56,
        height: 56,
        child: photo == null
            ? ColoredBox(
                color: AppColors.bgSurfaceAlt,
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.textSecondary,
                ),
              )
            : Image.file(photo!.file, fit: BoxFit.cover),
      ),
    );
  }
}
