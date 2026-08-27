import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme.dart';
import 'camera_session.dart';
import 'capture_frame_overlay.dart';
import 'capture_spec.dart';
import 'frame_recognizer.dart';

/// Full-resolution capture with a guide frame, then recognition.
///
/// Pops the recogniser's result, or null if the user backed out.
///
/// Knows nothing about documents. It is handed a [CaptureSpec] describing what
/// is being photographed and a [FrameRecognizer] describing what to do with the
/// photo, and it does the rest: camera lifecycle, permissions, the guide frame,
/// the shutter, and the "working" overlay. Adding a plate recogniser means
/// writing a `FrameRecognizer<PlateReading>` and constructing this with it —
/// no change here.
///
/// Recognition runs at capture time rather than at submit time so a photo that
/// could not be read is caught while the subject is still in front of the user.
///
/// The viewfinder is dark in both themes, so everything on it reads from
/// `t.text.onDark` rather than the ordinary text tokens — those would be
/// near-black in light mode and invisible against the preview.
class CameraCaptureScreen<T> extends StatefulWidget {
  const CameraCaptureScreen({
    super.key,
    required this.spec,
    required this.recognizer,
  });

  final CaptureSpec spec;

  /// Owned by the caller, not by this screen — usually a provider keeping one
  /// instance alive across a multi-capture flow, because constructing one per
  /// photo reloads the model each time. This screen never disposes it.
  final FrameRecognizer<T> recognizer;

  @override
  State<CameraCaptureScreen<T>> createState() => _CameraCaptureScreenState<T>();
}

class _CameraCaptureScreenState<T> extends State<CameraCaptureScreen<T>> {
  late final CameraSession _session = CameraSession(spec: widget.spec);
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _session.addListener(_onSessionChanged);
    _session.start();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _session.dispose();
    super.dispose();
  }

  void _onSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (_isBusy || !_session.isReady) return;

    setState(() => _isBusy = true);
    HapticFeedback.mediumImpact();

    final shot = await _session.capture();
    if (shot == null) {
      if (mounted) setState(() => _isBusy = false);
      return;
    }

    final result = await widget.recognizer.recognize(File(shot.path));
    if (mounted) Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final controller = _session.controller;
    final failure = _session.failure;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The viewfinder is black whatever the app theme is doing, so the status
      // bar icons have to be light regardless.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: t.text.onDark,
          surfaceTintColor: Colors.transparent,
          iconTheme: IconThemeData(color: t.text.onDark),
          titleTextStyle:
              context.text.headlineSmall?.copyWith(color: t.text.onDark),
          title: Text(widget.spec.label),
        ),
        body: switch ((failure, controller)) {
          (final CameraFailure f, _) =>
            _CameraError(message: f.message, onRetry: _session.retry),
          (null, null) => _CameraStarting(),
          (null, final CameraController c) when !c.value.isInitialized =>
            _CameraStarting(),
          (null, final CameraController c) => _Viewfinder(
              controller: c,
              spec: widget.spec,
              isBusy: _isBusy,
              busyMessage: widget.recognizer.busyMessage,
              onCapture: _capture,
            ),
        },
      ),
    );
  }
}

class _Viewfinder extends StatelessWidget {
  const _Viewfinder({
    required this.controller,
    required this.spec,
    required this.isBusy,
    required this.busyMessage,
    required this.onCapture,
  });

  final CameraController controller;
  final CaptureSpec spec;
  final bool isBusy;
  final String busyMessage;
  final VoidCallback onCapture;

  @override
  Widget build(BuildContext context) {
    final preview = controller.value.previewSize;

    return Stack(
      fit: StackFit.expand,
      children: [
        FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            // previewSize is reported in the sensor's own orientation, which is
            // landscape even when the phone is held portrait — hence the swap.
            width: preview?.height ?? 1,
            height: preview?.width ?? 1,
            child: CameraPreview(controller),
          ),
        ),
        CaptureFrameOverlay(aspectRatio: spec.aspectRatio),
        _Instruction(text: spec.instruction),
        if (isBusy) _BusyOverlay(message: busyMessage),
        Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xl),
            child: _ShutterButton(onPressed: isBusy ? null : onCapture),
          ),
        ),
      ],
    );
  }
}

class _CameraStarting extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.tokens.text.onDark),
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
          style: context.text.bodyMedium
              ?.copyWith(color: context.tokens.text.onDark),
        ),
      ),
    );
  }
}

/// Covers the preview while recognition runs.
class _BusyOverlay extends StatelessWidget {
  const _BusyOverlay({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final onDark = context.tokens.text.onDark;

    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: onDark),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              style: context.text.bodyMedium?.copyWith(color: onDark),
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
    final enabled = onPressed != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: 'Take photo',
      child: GestureDetector(
        onTap: onPressed,
        child: Container(
          width: 76,
          height: 76,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: enabled ? Colors.white : Colors.white38,
            border: Border.all(color: Colors.white54, width: 4),
          ),
          child: const Icon(
            Icons.camera_alt,
            size: 32,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final onDark = context.tokens.text.onDark;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.no_photography,
              color: context.tokens.text.onDarkMuted,
              size: AppSizes.iconHero,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(color: onDark),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextButton(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: onDark),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
