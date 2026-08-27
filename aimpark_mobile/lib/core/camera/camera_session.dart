import 'package:camera/camera.dart';
import 'package:flutter/widgets.dart';

import 'capture_spec.dart';

/// Why the camera is unavailable, in words a user can act on.
enum CameraFailure {
  /// The device reported no cameras at all.
  none,

  /// The user declined, or revoked, the camera permission.
  permissionDenied,

  /// Anything else the plugin threw while starting up.
  startFailed,

  /// The shutter itself failed.
  captureFailed;

  String get message => switch (this) {
        CameraFailure.none => 'This device has no camera.',
        CameraFailure.permissionDenied =>
          'Camera access is off. Enable it for AimPark in Settings, then come '
              'back.',
        CameraFailure.startFailed => 'The camera could not be started.',
        CameraFailure.captureFailed =>
          'The photo could not be taken. Try again.',
      };
}

/// Owns a [CameraController] and its lifecycle.
///
/// Extracted from the capture screen's `State` so a second camera surface — a
/// live plate scanner, say — gets correct start-up, permission handling and
/// background/foreground behaviour without copying any of it. That copying is
/// the part most likely to go subtly wrong: the release-on-`inactive` dance
/// below is not obvious, and getting it wrong gives a frozen preview that only
/// shows up after the user switches apps.
///
/// A [ChangeNotifier] rather than a widget so it can drive a shutter screen, a
/// streaming screen, or a test.
class CameraSession extends ChangeNotifier with WidgetsBindingObserver {
  CameraSession({required this.spec});

  final CaptureSpec spec;

  CameraController? _controller;
  CameraFailure? _failure;
  bool _disposed = false;

  /// Null until the camera is ready. Callers must handle that.
  CameraController? get controller => _controller;

  bool get isReady => _controller?.value.isInitialized ?? false;

  CameraFailure? get failure => _failure;

  /// Starts observing lifecycle and opens the camera. Call from `initState`.
  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await _open();
  }

  /// Reopens after a failure. Wired to the error state's retry button.
  Future<void> retry() async {
    _failure = null;
    notifyListeners();
    await _open();
  }

  Future<void> _open() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _fail(CameraFailure.none);
        return;
      }

      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        back,
        spec.resolution,
        enableAudio: false,
      );

      await controller.initialize();
      if (spec.lockOrientation != null) {
        await controller.lockCaptureOrientation(spec.lockOrientation!);
      }

      // The widget may have gone while we were awaiting; leaking a live
      // controller keeps the camera open for the whole app.
      if (_disposed) {
        await controller.dispose();
        return;
      }

      _controller = controller;
      _failure = null;
      notifyListeners();
    } on CameraException catch (e) {
      _fail(
        e.code == 'CameraAccessDenied'
            ? CameraFailure.permissionDenied
            : CameraFailure.startFailed,
      );
    }
  }

  void _fail(CameraFailure failure) {
    if (_disposed) return;
    _failure = failure;
    _controller = null;
    notifyListeners();
  }

  /// Takes a photo, or null if the shutter failed. [failure] carries the
  /// reason when it does.
  Future<XFile?> capture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return null;

    try {
      return await controller.takePicture();
    } on CameraException {
      _fail(CameraFailure.captureFailed);
      return null;
    }
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
      notifyListeners();
    } else if (state == AppLifecycleState.resumed) {
      _open();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }
}
