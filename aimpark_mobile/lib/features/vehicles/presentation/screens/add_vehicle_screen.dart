import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/camera/camera_capture_screen.dart';
import '../../../../core/camera/capture_tips_preference.dart';
import '../../../../core/camera/capture_tips_sheet.dart';
import '../../../../core/camera/document_review_screen.dart';
import '../../../../core/ocr/document_recognizer.dart';
import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/utils/app_flushbar.dart';
import '../../../../core/widgets/widgets.dart';
import '../../../auth/data/models/document_spec.dart';
import '../../../auth/data/models/scan_result.dart';
import '../../../auth/presentation/providers/registration_provider.dart';
import '../../../auth/presentation/widgets/document_photo_panel.dart';
import '../providers/vehicles_provider.dart';
import 'confirm_vehicle_screen.dart';

/// Adding a vehicle: the receipt, and nothing about the person.
///
/// One document rather than the three registration asks for, because a second
/// vehicle raises no new question about its owner — their enrolment and
/// licence were read when they registered. What is unknown is which vehicle
/// this is, and that is precisely what the receipt answers.
class AddVehicleScreen extends ConsumerStatefulWidget {
  const AddVehicleScreen({super.key});

  @override
  ConsumerState<AddVehicleScreen> createState() => _AddVehicleScreenState();
}

class _AddVehicleScreenState extends ConsumerState<AddVehicleScreen> {
  static const _spec = DocumentSpec.officialReceipt;
  static const _tipsPreference = CaptureTipsPreference();

  CapturedDocument? _captured;
  bool _isSubmitting = false;

  Future<void> _capture() async {
    if (!await _tipsPreference.hasBeenShown()) {
      if (!mounted) return;
      final proceed = await CaptureTipsSheet.show(context);
      if (!proceed || !mounted) return;
      unawaited(_tipsPreference.markShown());
    }

    if (!mounted) return;
    final navigator = Navigator.of(context);

    while (mounted) {
      final captured = await navigator.push<CapturedDocument>(
        MaterialPageRoute(
          builder: (_) => CameraCaptureScreen<CapturedDocument>(
            spec: _spec,
            recognizer: DocumentRecognizer(
              ref.read(documentScannerProvider),
              _spec.type,
            ),
          ),
        ),
      );
      if (captured == null || !mounted) return;

      final useIt = await navigator.push<bool>(
        MaterialPageRoute(
          builder: (_) => DocumentReviewScreen(photo: captured, spec: _spec),
        ),
      );

      if (useIt == true) {
        setState(() => _captured = captured);
        return;
      }
      // Anything else goes round again rather than leaving the screen on a
      // photo the user just said no to.
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final photo = _captured!;
      final fields = <String, dynamic>{
        'OfficialReceipt': await MultipartFile.fromFile(photo.file.path),
      };
      final payload = photo.payload;
      if (payload != null) fields['OfficialReceiptOcr'] = payload.toJsonString();

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
      // photo has served its purpose and holding it would re-upload this
      // attempt's image on a second pass.
      if (mounted) setState(() => _captured = null);
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _captured?.isUsable == true && !_isSubmitting;

    return AppScreen(
      title: 'Add a vehicle',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppSectionHeader(
            title: 'Prove the vehicle',
            subtitle: _spec.purpose,
          ),
          Text(_spec.label, style: context.text.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(_spec.purpose, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          DocumentPhotoPanel(
            spec: _spec,
            photo: _captured,
            onCapture: _isSubmitting ? null : _capture,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Read my documents',
            isLoading: _isSubmitting,
            onPressed: canSubmit ? _submit : null,
          ),
          if (!canSubmit && !_isSubmitting)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                _captured == null
                    ? 'Still needed: ${_spec.label}.'
                    : 'Retake the photo above to continue.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
        ],
      ),
    );
  }
}
