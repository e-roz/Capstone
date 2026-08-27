import 'dart:io';

/// Turns a captured photo into whatever the calling flow needs from it.
///
/// This is the seam between "take a picture" and "understand the picture".
/// Before it existed, [CameraCaptureScreen]'s ancestor constructed a
/// `DocumentScanner` directly and popped a `CapturedDocument`, so adding a
/// second model meant either copying eighty lines of camera lifecycle code or
/// putting an `if (isPlate)` inside the capture screen.
///
/// A new recogniser is a new implementation of this and nothing else:
///
/// ```dart
/// class PlateRecognizer implements FrameRecognizer<PlateReading> {
///   @override
///   String get busyMessage => 'Reading the plate…';
///
///   @override
///   Future<PlateReading> recognize(File file) => _model.run(file);
///
///   @override
///   Future<void> dispose() => _model.close();
/// }
/// ```
///
/// Then `CameraCaptureScreen<PlateReading>(spec: …, recognizer: …)`.
///
/// ## Contract
///
/// [recognize] **must not throw**. A photo that could not be read is an
/// ordinary outcome, not an error: the registration flow submits the image
/// anyway and lets the user type the values, and a flow that threw here would
/// strand someone over a detail they cannot influence. Implementations report
/// failure inside their own result type.
abstract interface class FrameRecognizer<T> {
  /// What to show over the preview while [recognize] runs.
  ///
  /// Recognition of a full-resolution page took around five seconds in
  /// testing, which is far too long to leave unexplained.
  String get busyMessage;

  /// Reads [file] and returns the flow's result type.
  Future<T> recognize(File file);

  /// Releases the underlying model.
  ///
  /// Whoever *owns* the recogniser calls this — usually a Riverpod provider
  /// keeping one instance alive across a multi-screen flow, because
  /// constructing one per photo reloads the model each time. The capture
  /// screen never disposes a recogniser it was handed.
  Future<void> dispose();
}
