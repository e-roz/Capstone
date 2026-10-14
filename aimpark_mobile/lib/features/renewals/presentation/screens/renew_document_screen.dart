import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../../../auth/presentation/providers/registration_provider.dart';
import '../../../auth/presentation/widgets/document_photo_panel.dart';
import '../../data/renewal.dart';
import '../providers/renewals_provider.dart';
import 'confirm_renewal_screen.dart';

/// Photographing a renewed licence or registration.
///
/// Built like adding a vehicle: one document, read on the phone, then the date
/// is shown back for the user to confirm. The difference is where it ends. A
/// renewal goes to an admin, and nothing about the user's access changes until
/// it is approved.
class RenewDocumentScreen extends ConsumerStatefulWidget {
  const RenewDocumentScreen({super.key, required this.target});

  final RenewalTarget target;

  @override
  ConsumerState<RenewDocumentScreen> createState() =>
      _RenewDocumentScreenState();
}

class _RenewDocumentScreenState extends ConsumerState<RenewDocumentScreen> {
  static const _tipsPreference = CaptureTipsPreference();

  CapturedDocument? _captured;
  bool _isSubmitting = false;

  DocumentSpec get _spec => widget.target.kind == RenewalKind.license
      ? DocumentSpec.license
      : DocumentSpec.officialReceipt;

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
    }
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);

    try {
      final photo = _captured!;
      final target = widget.target;

      final fields = <String, dynamic>{
        'Document': await MultipartFile.fromFile(photo.file.path),
        'Kind': target.kind.wireName,
        if (target.vehicleId != null) 'VehicleId': target.vehicleId,
      };
      final payload = photo.payload;
      if (payload != null) fields['DocumentOcr'] = payload.toJsonString();

      final response = await ref
          .read(renewalsRepositoryProvider)
          .scan(FormData.fromMap(fields));
      final scan = RenewalScan.fromJson(response.data as Map<String, dynamic>);

      if (!mounted) return;

      // Retakes are unlimited: this user already has an account, so an
      // unreadable photo costs another attempt, not a place in the queue.
      if (!scan.canContinue) {
        showAppMessage(
          context,
          scan.problems.isEmpty
              ? 'That photo could not be read. Try again in better light.'
              : scan.problems.first,
          isError: true,
        );
        return;
      }

      final sent = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => ConfirmRenewalScreen(scan: scan, target: target),
        ),
      );

      if (!mounted) return;

      if (sent == true) {
        context.pop();
      } else {
        // Abandoned: the photo has served its purpose, and holding it would
        // upload this attempt's image again.
        setState(() => _captured = null);
      }
    } catch (e) {
      if (mounted) showApiError(context, e);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _captured?.isUsable == true && !_isSubmitting;
    final target = widget.target;

    return AppScreen(
      title: 'Renew ${target.kind == RenewalKind.license ? 'licence' : 'registration'}',
      body: ListView(
        padding: kScreenListPadding,
        children: [
          AppSectionHeader(
            title: target.title,
            subtitle: target.kind == RenewalKind.license
                ? 'Photograph your renewed licence. Your old one stays in force '
                    'until an admin approves this.'
                : 'Photograph the new receipt for this vehicle. Your current '
                    'registration stays in force until an admin approves this.',
          ),
          Text(_spec.label, style: context.text.labelLarge),
          const SizedBox(height: AppSpacing.xs),
          Text(_spec.instruction, style: context.text.bodySmall),
          const SizedBox(height: AppSpacing.sm),
          DocumentPhotoPanel(
            spec: _spec,
            photo: _captured,
            onCapture: _isSubmitting ? null : _capture,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Read my document',
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
