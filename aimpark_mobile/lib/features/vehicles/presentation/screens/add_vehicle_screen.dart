import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/camera/camera_capture_screen.dart';
import '../../../../core/ocr/document_recognizer.dart';
import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/document_spec.dart';
import '../../../auth/data/models/scan_result.dart';
import '../../../auth/presentation/providers/registration_provider.dart';
import '../../../auth/presentation/widgets/document_photo_panel.dart';
import '../providers/vehicles_provider.dart';
import 'confirm_vehicle_screen.dart';

/// Adding a vehicle: the receipt, the plate, and nothing about the person.
///
/// Two documents rather than the four registration asks for, because a second
/// vehicle raises no new question about its owner — their enrolment and licence
/// were read when they registered. What is unknown is which vehicle this is,
/// and that is precisely what the receipt and the plate answer.
///
/// Both photographs on one screen rather than one per screen as in
/// registration: the sequencing there exists to keep four documents from
/// arriving as one wall of demands, and two do not need it.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  static const _specs = [
    DocumentSpec.officialReceipt,
    DocumentSpec.platePhoto,
  ];

  final _captured = <ScanDocumentType, CapturedDocument>{};
  bool _isSubmitting = false;

  Future<void> _capture(DocumentSpec spec) async {
    final result = await Navigator.of(context).push<CapturedDocument>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen<CapturedDocument>(
          spec: spec,
          recognizer: DocumentRecognizer(
            ref.read(documentScannerProvider),
            spec.type,
          ),
        ),
      ),
    );

    if (result == null || !mounted) return;
    setState(() => _captured[spec.type] = result);
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final fields = <String, dynamic>{};
      for (final spec in _specs) {
        final photo = _captured[spec.type]!;
        final field = switch (spec.type) {
          ScanDocumentType.officialReceipt => 'OfficialReceipt',
          _ => 'PlatePhoto',
        };
        fields[field] = await MultipartFile.fromFile(photo.file.path);
        final payload = photo.payload;
        if (payload != null) fields['${field}Ocr'] = payload.toJsonString();
      }

      final response = await ref
          .read(vehiclesRepositoryProvider)
          .scanDocuments(FormData.fromMap(fields));

      final result = ScanResult.fromJson(response.data as Map<String, dynamic>);

      if (!mounted) return;

      // Unlike registration there is no retake limit to fail open against — this
      // user already has an account, so an unreadable receipt costs them another
      // attempt rather than stranding them mid-signup.
      if (!result.canContinue) {
        final problem = result.diagnostics.isEmpty
            ? 'Those photos could not be read. Try again in better light.'
            : result.diagnostics.first.message;
        showAppMessage(context, problem, isError: true);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ConfirmVehicleScreen(result: result),
        ),
      );

      // Coming back means it was either committed or abandoned. Either way the
      // photos have served their purpose and holding them would re-upload this
      // attempt's images on a second pass.
      if (mounted) setState(_captured.clear);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final missing = _specs.where((s) => !_captured.containsKey(s.type)).toList();
    final unusable = _specs
        .where((s) => _captured[s.type]?.isUsable == false)
        .toList();
    final canSubmit = missing.isEmpty && unusable.isEmpty && !_isSubmitting;

    return AppScreen(
      title: 'Add a vehicle',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          const AppSectionHeader(
            title: 'Prove the vehicle',
            subtitle: 'The plate is read from your receipt and checked against '
                'the photo of the plate itself, so you never type it.',
          ),
          for (final spec in _specs) ...[
            Text(spec.label, style: context.text.labelLarge),
            const SizedBox(height: AppSpacing.xs),
            Text(spec.purpose, style: context.text.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            DocumentPhotoPanel(
              spec: spec,
              photo: _captured[spec.type],
              onCapture: _isSubmitting ? null : () => _capture(spec),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          AppButton(
            label: 'Read my documents',
            isLoading: _isSubmitting,
            onPressed: canSubmit ? _submit : null,
          ),
          if (!canSubmit && !_isSubmitting)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                missing.isNotEmpty
                    ? 'Still needed: ${missing.map((s) => s.label).join(', ')}.'
                    : 'Retake the photos marked above to continue.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
