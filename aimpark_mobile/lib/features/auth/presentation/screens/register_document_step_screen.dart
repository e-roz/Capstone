import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/api_error_message.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/app_button.dart';
import '../../data/models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/registration_step_scaffold.dart';
import 'document_capture_screen.dart';
import 'register_confirm_screen.dart';

/// The documents registration asks for, in the order they are asked for.
///
/// Students prove enrolment with a registration form; everyone else brings a
/// school ID, which is filed but not read.
List<DocumentSpec> documentSpecsFor(Affiliation affiliation) => [
  affiliation == Affiliation.student ? DocumentSpec.raf : DocumentSpec.schoolId,
  DocumentSpec.license,
  DocumentSpec.officialReceipt,
  DocumentSpec.platePhoto,
];

/// One document, one screen.
///
/// This used to be a single screen with four tiles on it, which asked someone
/// to hold four documents in their head at once and gave no sense of progress.
/// Split up, each screen has one job and can say what that document is for.
///
/// The photos are not uploaded as they are taken. They collect in
/// [RegistrationNotifier] and go up in one call from the last screen, which
/// keeps the server's single scan endpoint and means the retake verdicts all
/// arrive together rather than four separate waits.
class RegisterDocumentStepScreen extends ConsumerStatefulWidget {
  const RegisterDocumentStepScreen({
    super.key,
    required this.index,
    this.retakeMessage,
  });

  /// Position in [documentSpecsFor], 0-3.
  final int index;

  /// The server's own wording for why this document came back, when the flow
  /// has jumped here from the end of the sequence.
  final String? retakeMessage;

  @override
  ConsumerState<RegisterDocumentStepScreen> createState() =>
      _RegisterDocumentStepScreenState();
}

class _RegisterDocumentStepScreenState
    extends ConsumerState<RegisterDocumentStepScreen> {
  bool _isSubmitting = false;

  /// Set when the server sends this document back for a retake.
  String? _retakeMessage;

  @override
  void initState() {
    super.initState();
    _retakeMessage = widget.retakeMessage;
  }

  Future<void> _capture(DocumentSpec spec) async {
    final result = await Navigator.of(context).push<CapturedDocument>(
      MaterialPageRoute(
        builder: (_) => DocumentCaptureScreen(
          spec: spec,
          scanner: ref.read(documentScannerProvider),
        ),
      ),
    );
    if (result == null || !mounted) return;

    ref.read(registrationNotifierProvider.notifier).setCaptured(spec.type, result);

    // The verdict described the previous photo. Leaving it up would tell someone
    // their retake is still blurry before anyone has looked at it.
    setState(() => _retakeMessage = null);
  }

  /// Names each photo the way the server's multipart form expects.
  String _fieldFor(ScanDocumentType type) => switch (type) {
    ScanDocumentType.raf || ScanDocumentType.schoolId => 'IdentityDocument',
    ScanDocumentType.license => 'License',
    ScanDocumentType.officialReceipt => 'OfficialReceipt',
    ScanDocumentType.platePhoto => 'PlatePhoto',
  };

  Future<String?> _oversizedPhoto(
    List<DocumentSpec> specs,
    Map<ScanDocumentType, CapturedDocument> captured,
  ) async {
    const limitBytes = 8 * 1024 * 1024;
    for (final spec in specs) {
      final photo = captured[spec.type];
      if (photo == null) continue;
      if (await photo.file.length() > limitBytes) return spec.label;
    }
    return null;
  }

  /// Uploads all four and opens the summary. Only ever called from the last
  /// screen in the sequence.
  Future<void> _submitAll(List<DocumentSpec> specs) async {
    final captured = ref.read(registrationNotifierProvider).captured;

    final missing = specs.where((s) => !captured.containsKey(s.type)).toList();
    if (missing.isNotEmpty) {
      showAppMessage(
        context,
        'Still needed: ${missing.map((s) => s.label).join(', ')}.',
        isError: true,
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      // The server rejects anything over 8MB per file. Caught here so a
      // high-megapixel phone gets a sentence it can act on instead of a 400.
      final oversized = await _oversizedPhoto(specs, captured);
      if (oversized != null) {
        if (mounted) {
          showAppMessage(
            context,
            'The $oversized photo is too large to upload. Retake it a little '
            'further from the document.',
            isError: true,
          );
        }
        return;
      }

      final fields = <String, dynamic>{};
      for (final spec in specs) {
        final photo = captured[spec.type]!;
        final field = _fieldFor(spec.type);
        fields[field] = await MultipartFile.fromFile(photo.file.path);
        final payload = photo.payload;
        if (payload != null) {
          fields['${field}Ocr'] = payload.toJsonString();
        }
      }

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.scanDocuments(FormData.fromMap(fields));
      final result = ScanResult.fromJson(response.data as Map<String, dynamic>);

      if (!mounted) return;

      if (!result.canContinue) {
        _sendBackForRetakes(specs, result);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => RegisterConfirmScreen(result: result)),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Walks the user back to the first document that needs another photograph.
  ///
  /// With one document per screen there is nowhere to list four verdicts at
  /// once, and there is no reason to: the fix is per-document, so the flow goes
  /// to the document that needs fixing and says why on that screen.
  void _sendBackForRetakes(List<DocumentSpec> specs, ScanResult result) {
    final byType = {for (final d in result.diagnostics) d.documentType: d};

    for (var i = 0; i < specs.length; i++) {
      final spec = specs[i];

      // The server reports the identity slot under whichever kind the account
      // files under, decided from the affiliation on record rather than the one
      // this flow guessed — so accept either name there.
      final isIdentity =
          spec.type == ScanDocumentType.raf ||
          spec.type == ScanDocumentType.schoolId;

      final diagnosis = isIdentity
          ? byType[ScanDocumentType.raf.wireName] ??
                byType[ScanDocumentType.schoolId.wireName]
          : byType[spec.type.wireName];

      if (diagnosis == null) continue;

      final tries =
          '${result.triesLeft} ${result.triesLeft == 1 ? 'try' : 'tries'} left';

      if (i == widget.index) {
        setState(() => _retakeMessage = '${diagnosis.message} ($tries)');
      } else {
        context.go('/register/documents/$i', extra: '${diagnosis.message} ($tries)');
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final affiliation = ref.watch(
      registrationNotifierProvider.select((s) => s.affiliation),
    );
    final captured = ref.watch(
      registrationNotifierProvider.select((s) => s.captured),
    );

    final specs = documentSpecsFor(affiliation);
    final spec = specs[widget.index];
    final photo = captured[spec.type];
    final isLast = widget.index == specs.length - 1;

    return RegistrationStepScaffold(
      step: 4,
      title: 'Documents',
      subStep: '${widget.index + 1} of ${specs.length}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(spec.label, style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            spec.purpose,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),

          _PhotoPanel(
            spec: spec,
            photo: photo,
            onCapture: _isSubmitting ? null : () => _capture(spec),
          ),

          if (_retakeMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            _RetakeNotice(message: _retakeMessage!),
          ],

          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: isLast ? 'Read my documents' : 'Continue',
            isLoading: _isSubmitting,
            onPressed: photo == null || _isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _submitAll(specs);
                    } else {
                      context.go('/register/documents/${widget.index + 1}');
                    }
                  },
          ),
          if (photo == null)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Take the photo to continue.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// The capture target: an empty prompt before, the photograph after.
class _PhotoPanel extends StatelessWidget {
  const _PhotoPanel({
    required this.spec,
    required this.photo,
    required this.onCapture,
  });

  final DocumentSpec spec;
  final CapturedDocument? photo;
  final VoidCallback? onCapture;

  @override
  Widget build(BuildContext context) {
    if (photo == null) {
      return InkWell(
        onTap: onCapture,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 220,
          decoration: BoxDecoration(
            color: AppColors.bgSurface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderDefault),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.photo_camera_outlined,
                size: 40,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.sm),
              Text('Take a photo', style: AppTextStyles.labelBold),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                ),
                child: Text(
                  spec.instruction,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final lineCount = photo!.payload?.lines.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.file(
            File(photo!.file.path),
            height: 220,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            Icon(
              lineCount > 0 ? Icons.check_circle : Icons.info_outline,
              size: 18,
              color: lineCount > 0
                  ? AppColors.successDefault
                  : AppColors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                // Deliberately not a verdict. Whether the document is good
                // enough is the server's call, made when all four go up; this
                // only says the phone saw writing on it.
                lineCount > 0
                    ? 'Photo taken — text found on it.'
                    : 'Photo taken, but no text was picked up. A retake may help.',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(onPressed: onCapture, child: const Text('Retake')),
          ],
        ),
      ],
    );
  }
}

class _RetakeNotice extends StatelessWidget {
  const _RetakeNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline,
            size: 20,
            color: AppColors.errorDefault,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.errorDefault,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
