import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
import '../widgets/document_capture_tile.dart';
import '../widgets/registration_step_scaffold.dart';
import 'document_capture_screen.dart';
import 'register_confirm_screen.dart';

/// Collects the four photos registration needs and sends them to be read.
///
/// Each is captured through [DocumentCaptureScreen] rather than the gallery
/// picker: the picker downscales, and small print on a receipt does not survive
/// that. What the server reads back is confirmed on the next screen.
class RegisterDocumentsScreen extends ConsumerStatefulWidget {
  const RegisterDocumentsScreen({super.key});

  @override
  ConsumerState<RegisterDocumentsScreen> createState() =>
      _RegisterDocumentsScreenState();
}

class _RegisterDocumentsScreenState
    extends ConsumerState<RegisterDocumentsScreen> {
  /// One recogniser for the whole step, so the model is loaded once rather than
  /// once per photo.
  final DocumentScanner _scanner = DocumentScanner();

  final Map<ScanDocumentType, CapturedDocument> _captured = {};

  /// Keyed by the server's document type name, as sent in the diagnostics.
  Map<String, DocumentDiagnosis> _diagnostics = {};

  bool _isSubmitting = false;

  @override
  void dispose() {
    _scanner.dispose();
    super.dispose();
  }

  List<DocumentSpec> _specsFor(Affiliation affiliation) => [
    affiliation == Affiliation.student
        ? DocumentSpec.raf
        : DocumentSpec.schoolId,
    DocumentSpec.license,
    DocumentSpec.officialReceipt,
    DocumentSpec.platePhoto,
  ];

  Future<void> _capture(DocumentSpec spec) async {
    final result = await Navigator.of(context).push<CapturedDocument>(
      MaterialPageRoute(
        builder: (_) => DocumentCaptureScreen(spec: spec, scanner: _scanner),
      ),
    );
    if (result == null || !mounted) return;

    setState(() {
      _captured[spec.type] = result;
      // The previous verdict described the previous photo. Leaving it up would
      // tell someone their retake is still blurry before it has been looked at.
      _diagnostics = {};
    });
  }

  /// Names each photo the way the server's multipart form expects.
  String _fieldFor(ScanDocumentType type) => switch (type) {
    ScanDocumentType.raf || ScanDocumentType.schoolId => 'IdentityDocument',
    ScanDocumentType.license => 'License',
    ScanDocumentType.officialReceipt => 'OfficialReceipt',
    ScanDocumentType.platePhoto => 'PlatePhoto',
  };

  Future<String?> _oversizedPhoto(List<DocumentSpec> specs) async {
    const limitBytes = 8 * 1024 * 1024;
    for (final spec in specs) {
      final captured = _captured[spec.type];
      if (captured == null) continue;
      if (await captured.file.length() > limitBytes) return spec.label;
    }
    return null;
  }

  Future<void> _submit(List<DocumentSpec> specs) async {
    final missing = specs.where((s) => !_captured.containsKey(s.type)).toList();
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
      final oversized = await _oversizedPhoto(specs);
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
        final captured = _captured[spec.type]!;
        final field = _fieldFor(spec.type);
        fields[field] = await MultipartFile.fromFile(captured.file.path);
        final payload = captured.payload;
        if (payload != null) {
          fields['${field}Ocr'] = payload.toJsonString();
        }
      }

      final repo = ref.read(authRepositoryProvider);
      final response = await repo.scanDocuments(FormData.fromMap(fields));
      final result = ScanResult.fromJson(response.data as Map<String, dynamic>);

      if (!mounted) return;

      if (!result.canContinue) {
        setState(() {
          _diagnostics = {
            for (final d in result.diagnostics) d.documentType: d,
          };
        });
        showAppMessage(
          context,
          'Some photos need retaking. ${result.triesLeft} '
          '${result.triesLeft == 1 ? 'try' : 'tries'} left.',
          isError: true,
        );
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => RegisterConfirmScreen(result: result),
        ),
      );
    } catch (e) {
      if (mounted) showAppMessage(context, apiErrorMessage(e), isError: true);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// The server names a diagnostic by document type. For the identity slot it
  /// reports whichever kind the account files under, which is decided from the
  /// affiliation on record rather than the one this screen guessed — so accept
  /// either name there.
  DocumentDiagnosis? _diagnosisFor(DocumentSpec spec) {
    final isIdentity =
        spec.type == ScanDocumentType.raf ||
        spec.type == ScanDocumentType.schoolId;

    if (isIdentity) {
      return _diagnostics[ScanDocumentType.raf.wireName] ??
          _diagnostics[ScanDocumentType.schoolId.wireName];
    }
    return _diagnostics[spec.type.wireName];
  }

  @override
  Widget build(BuildContext context) {
    final affiliation = ref.watch(
      registrationNotifierProvider.select((s) => s.affiliation),
    );
    final specs = _specsFor(affiliation);

    return RegistrationStepScaffold(
      step: 5,
      title: 'Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Photograph your documents', style: AppTextStyles.h2),
          const SizedBox(height: AppSpacing.xs),
          Text(
            "We'll read them on your phone and show you what we found, so you "
            'can correct anything before it is submitted.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          for (final spec in specs) ...[
            DocumentCaptureTile(
              spec: spec,
              captured: _captured[spec.type],
              diagnosis: _diagnosisFor(spec),
              onCapture: _isSubmitting ? null : () => _capture(spec),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          const SizedBox(height: AppSpacing.sm),
          AppButton(
            label: 'Read my documents',
            isLoading: _isSubmitting,
            onPressed: _isSubmitting ? null : () => _submit(specs),
          ),
        ],
      ),
    );
  }
}
