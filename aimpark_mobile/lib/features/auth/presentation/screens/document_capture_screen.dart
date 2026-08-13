import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/ocr/document_scanner.dart';
import '../../../../core/ocr/ocr_payload.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../widgets/capture_frame_overlay.dart';

/// What the capture screen needs to know about one document.
class DocumentSpec {
  const DocumentSpec({
    required this.type,
    required this.label,
    required this.instruction,
    required this.aspectRatio,
  });

  final ScanDocumentType type;

  /// Short name, used in the app bar and on the picker tile.
  final String label;

  /// One line telling the user how to hold the document.
  final String instruction;

  /// Width over height of the physical document, for the guide frame.
  final double aspectRatio;

  /// A4-ish, portrait.
  static const raf = DocumentSpec(
    type: ScanDocumentType.raf,
    label: 'Registration form',
    instruction: 'Lay it flat and fit the whole form inside the frame.',
    aspectRatio: 1 / 1.414,
  );

  static const schoolId = DocumentSpec(
    type: ScanDocumentType.schoolId,
    label: 'School ID',
    instruction: 'Front of your school ID, filling the frame.',
    aspectRatio: 1.586,
  );

  static const license = DocumentSpec(
    type: ScanDocumentType.license,
    label: "Driver's licence",
    instruction: 'Front of your licence, with the expiry date visible.',
    aspectRatio: 1.586,
  );

  static const officialReceipt = DocumentSpec(
    type: ScanDocumentType.officialReceipt,
    label: 'Official receipt',
    instruction: 'The LTO receipt. Keep the plate number and date in frame.',
    aspectRatio: 1 / 1.414,
  );

  static const platePhoto = DocumentSpec(
    type: ScanDocumentType.platePhoto,
    label: 'Plate photo',
    instruction: 'The plate on the vehicle itself, straight on and close up.',
    aspectRatio: 2.0,
  );
}

/// Full-resolution document capture with a guide frame and on-device reading.
///
/// Pops a [CapturedDocument], or null if the user backed out. Text recognition
/// runs here rather than at submit time so a photo that could not be read is
/// caught while the document is still in the user's hand.
class DocumentCaptureScreen extends StatefulWidget {
  const DocumentCaptureScreen({super.key, required this.spec, this.scanner});

  final DocumentSpec spec;

  /// Reused across captures when supplied. Left null the screen makes its own
  /// and disposes it, which reloads the recognition model per photo.
  final DocumentScanner? scanner;

  @override
  State<DocumentCaptureScreen> createState() => _DocumentCaptureScreenState();
}

class _DocumentCaptureScreenState extends State<DocumentCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  DocumentScanner? _ownedScanner;

  bool _isBusy = false;
  String? _error;

  DocumentScanner get _scanner =>
      widget.scanner ?? (_ownedScanner ??= DocumentScanner());

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _ownedScanner?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    // The camera is released to other apps on the way out and rebuilt on the
    // way back; reusing the old controller after that gives a frozen preview.
    if (state == AppLifecycleState.inactive) {
      _controller = null;
      controller.dispose();
      if (mounted) setState(() {});
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  Future<void> _startCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'This device has no camera.');
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        // Resolution is what makes small print and a plate legible. The
        // picker's downscaled output was the reason reads were failing.
        ResolutionPreset.max,
        enableAudio: false,
      );

      await controller.initialize();
      // Documents are photographed portrait. Locking it keeps the saved image
      // upright, so the server's "is the page sideways" check reflects how the
      // document was held rather than how the phone was tilted.
      await controller.lockCaptureOrientation(DeviceOrientation.portraitUp);

      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _error = null;
      });
    } on CameraException catch (e) {
      if (!mounted) return;
      setState(
        () => _error = e.code == 'CameraAccessDenied'
            ? 'Camera access is off. Enable it for AimPark in Settings, then come back.'
            : 'The camera could not be started.',
      );
    }
  }

  Future<void> _capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _isBusy) return;

    setState(() => _isBusy = true);
    try {
      final shot = await controller.takePicture();
      final result = await _scanner.scan(File(shot.path), widget.spec.type);
      if (mounted) Navigator.of(context).pop(result);
    } on CameraException {
      if (mounted) {
        setState(() {
          _isBusy = false;
          _error = 'The photo could not be taken. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.spec.label),
      ),
      body: _error != null
          ? _ErrorState(message: _error!, onRetry: _startCamera)
          : controller == null || !controller.value.isInitialized
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : Stack(
              fit: StackFit.expand,
              children: [
                FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: controller.value.previewSize?.height ?? 1,
                    height: controller.value.previewSize?.width ?? 1,
                    child: CameraPreview(controller),
                  ),
                ),
                CaptureFrameOverlay(aspectRatio: widget.spec.aspectRatio),
                _Instruction(text: widget.spec.instruction),
                if (_isBusy) const _ReadingOverlay(),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xl),
                    child: _ShutterButton(
                      onPressed: _isBusy ? null : _capture,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Instruction extends StatelessWidget {
  const _Instruction({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Covers the preview while recognition runs. A full-resolution page took
/// around five seconds in testing, which is far too long to leave unexplained.
class _ReadingOverlay extends StatelessWidget {
  const _ReadingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: Colors.white),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Reading the document…',
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  const _ShutterButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 76,
        height: 76,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: onPressed == null ? Colors.white38 : Colors.white,
          border: Border.all(color: Colors.white54, width: 4),
        ),
        child: const Icon(Icons.camera_alt, size: 32, color: Colors.black87),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography, color: Colors.white70, size: 48),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(color: Colors.white),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(onPressed: onRetry, child: const Text('Try again')),
          ],
        ),
      ),
    );
  }
}
