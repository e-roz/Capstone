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
import '../../../../router/registration_back_stack.dart';
import '../../data/models/document_spec.dart';
import '../../data/models/scan_result.dart';
import '../providers/auth_provider.dart';
import '../providers/registration_provider.dart';
import '../widgets/document_photo_panel.dart';
import '../widgets/registration_step_scaffold.dart';
import 'register_confirm_screen.dart';

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

  /// Position in [DocumentSpec.forAffiliation], 0-3.
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
  /// Photographs of one document before the flow stops asking for another.
  ///
  /// Mirrors the server's own limit, and exists for the same reason: the checks
  /// are derived from the documents that were on hand when they were written, so
  /// a form printed to a template nobody has seen must not be able to lock a
  /// real applicant out. After this many tries the photo is sent as it is and
  /// the reviewer is told the system could not recognise it.
  static const int _maxCaptureAttempts = 3;

  bool _isSubmitting = false;

  /// Set when the server sends this document back for a retake.
  String? _retakeMessage;

  @override
  void initState() {
    super.initState();
    _retakeMessage = widget.retakeMessage;
  }

  Future<void> _capture(DocumentSpec spec) async {
    final result =
        await Navigator.of(context).push<CapturedDocument>(
      MaterialPageRoute(
        builder: (_) => CameraCaptureScreen<CapturedDocument>(
          spec: spec,
          // The scanner is shared across all four captures by the provider;
          // this only binds it to the document being photographed now.
          recognizer: DocumentRecognizer(
            ref.read(documentScannerProvider),
            spec.type,
          ),
        ),
      ),
    );
    if (result == null || !mounted) return;

    ref.read(registrationNotifierProvider.notifier).setCaptured(
          spec.type,
          result,
        );

    // The verdict described the previous photo. Leaving it up would tell
    // someone their retake is still blurry before anyone has looked at it.
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
        MaterialPageRoute(
          builder: (_) => RegisterConfirmScreen(result: result),
        ),
      );
    } catch (e) {
      if (mounted) showApiError(context, e);
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
      final isIdentity = spec.type == ScanDocumentType.raf ||
          spec.type == ScanDocumentType.schoolId;

      final diagnosis = isIdentity
          ? byType[ScanDocumentType.raf.wireName] ??
              byType[ScanDocumentType.schoolId.wireName]
          : byType[spec.type.wireName];

      if (diagnosis == null) continue;

      final tries =
          '${result.triesLeft} ${result.triesLeft == 1 ? 'try' : 'tries'} left';
      final message = '${diagnosis.message} ($tries)';

      if (i == widget.index) {
        setState(() => _retakeMessage = message);
      } else {
        context.goRegistrationStep('/register/documents/$i', extra: message);
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final captured = ref.watch(
      registrationNotifierProvider.select((s) => s.captured),
    );

    final attempts = ref.watch(
      registrationNotifierProvider.select((s) => s.captureAttempts),
    );

    final hydrated = ref.watch(
      registrationNotifierProvider.select((s) => s.hydrated),
    );

    final agenda = ref.watch(documentAgendaProvider);

    // Photos taken before the app was killed are still being read back off
    // disk, and the server has not yet said whether a reviewer asked for
    // anything specific. Rendering the empty prompt first would invite someone
    // to re-photograph a document they had already done, or to photograph four
    // when only one was wanted.
    if (!hydrated || agenda.isLoading) return const _DocumentStepLoading();

    final specs = agenda.valueOrNull?.specs ??
        DocumentSpec.forAffiliation(
          ref.read(registrationNotifierProvider).affiliation,
        );

    // A retake list is shorter than the full set, and the route's index survives
    // from whatever the user was doing before. Clamped rather than trusted.
    if (widget.index >= specs.length) {
      return _DocumentStepOutOfRange(lastIndex: specs.length - 1);
    }

    final spec = specs[widget.index];
    final reviewerNote = agenda.valueOrNull?.reasons[spec.type];
    final photo = captured[spec.type];
    final isLast = widget.index == specs.length - 1;

    final retakesSpent = (attempts[spec.type] ?? 0) >= _maxCaptureAttempts;

    // The photo has to be readable and the right document before the flow moves
    // on. Once the retakes are spent it goes up regardless — a check derived
    // from a handful of sample forms is not grounds for refusing to register
    // someone, only for telling a reviewer it could not be confirmed.
    final canProceed = photo != null && (photo.isUsable || retakesSpent);

    return RegistrationStepScaffold(
      step: 4,
      title: 'Documents',
      subStep: '${widget.index + 1} of ${specs.length}',
      // Back walks the flow's history, so a document can be looked at or
      // retaken after moving past it, and the first of them returns to the
      // profile step — which reopens as an edit of the account that step
      // created rather than as a second submission of it.
      //
      // That step is where affiliation is chosen, and affiliation is what
      // decides which documents this screen asks for — so without a way back to
      // it, someone who picked the wrong one was being asked for a document
      // they do not have, on a screen with no way out.
      busy: _isSubmitting,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RegistrationStepHeading(
            title: spec.label,
            subtitle: spec.purpose,
          ),
          // The reviewer's own words, above the frame rather than below it: this
          // is the instruction for the photograph about to be taken, not a
          // verdict on one already taken.
          if (reviewerNote != null && reviewerNote.isNotEmpty) ...[
            AppNotice(
              title: 'The reviewer asked for this again',
              message: reviewerNote,
              intent: StatusIntent.warning,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          DocumentPhotoPanel(
            spec: spec,
            photo: photo,
            retakesSpent: retakesSpent,
            onCapture: _isSubmitting ? null : () => _capture(spec),
          ),
          if (_retakeMessage != null) ...[
            const SizedBox(height: AppSpacing.md),
            AppNotice(
              message: _retakeMessage!,
              intent: StatusIntent.danger,
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          AppButton(
            label: isLast ? 'Read my documents' : 'Continue',
            isLoading: _isSubmitting,
            onPressed: !canProceed || _isSubmitting
                ? null
                : () {
                    if (isLast) {
                      _submitAll(specs);
                    } else {
                      context.goRegistrationStep(
                        '/register/documents/${widget.index + 1}',
                      );
                    }
                  },
          ),
          if (!canProceed)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                photo == null
                    ? 'Take the photo to continue.'
                    : 'Retake this one to continue.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
        ],
      ),
    );
  }
}

/// Held while the saved draft is read back.
///
/// Deliberately the step's own frame rather than a bare spinner: this is what a
/// returning user sees first, and dropping them onto an unrecognisable loading
/// screen would make a resumed registration feel like a restarted one. The
/// substep is unknown until the affiliation is back, so the frame shows the
/// step alone.
/// Shown when the route asks for a document this pass does not want.
///
/// Reachable in one real way: a reviewer asks for one document, and the app is
/// resumed on a route that still names the third of four. Better to offer the
/// way back than to crash on the index or silently rewrite the URL under them.
class _DocumentStepOutOfRange extends StatelessWidget {
  const _DocumentStepOutOfRange({required this.lastIndex});

  final int lastIndex;

  @override
  Widget build(BuildContext context) {
    return RegistrationStepScaffold(
      step: 4,
      title: 'Documents',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AppNotice(
            message: 'There are fewer documents to take than there were last '
                'time — a reviewer only asked for some of them.',
            intent: StatusIntent.info,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Go to what is needed',
            onPressed: () =>
                context.jumpRegistrationStep('/register/documents/$lastIndex'),
          ),
        ],
      ),
    );
  }
}

class _DocumentStepLoading extends StatelessWidget {
  const _DocumentStepLoading();

  @override
  Widget build(BuildContext context) {
    return const RegistrationStepScaffold(
      step: 4,
      title: 'Documents',
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
