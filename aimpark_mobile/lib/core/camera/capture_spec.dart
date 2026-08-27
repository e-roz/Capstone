import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

/// Everything the capture screen needs to know about what it is photographing.
///
/// Deliberately says nothing about *documents*. The registration flow extends
/// this with its own document fields; a plate recogniser can use it as-is or
/// extend it differently. The capture pipeline should never have to know which
/// of those it is serving.
class CaptureSpec {
  const CaptureSpec({
    required this.label,
    required this.instruction,
    required this.aspectRatio,
    this.lockOrientation = DeviceOrientation.portraitUp,
    this.resolution = ResolutionPreset.max,
  });

  /// Short name, shown in the app bar.
  final String label;

  /// One line telling the user how to hold the subject.
  final String instruction;

  /// Width over height of the guide frame.
  final double aspectRatio;

  /// Orientation the saved image is locked to, or null to follow the device.
  ///
  /// Documents are photographed portrait, and locking keeps the saved image
  /// upright so the server's "is the page sideways" check reflects how the
  /// document was held rather than how the phone was tilted. A plate is
  /// landscape and wants a different answer — which is why this is a knob
  /// rather than a hardcoded `portraitUp` inside the capture screen.
  final DeviceOrientation? lockOrientation;

  /// Capture resolution.
  ///
  /// [ResolutionPreset.max] is right for a document, where small print has to
  /// survive: the image picker's downscaled output was the reason reads were
  /// failing. It is the wrong answer for anything recognising continuously —
  /// a full-resolution recognition pass took around five seconds in testing,
  /// so a live recogniser should drop this to `high` or lower.
  final ResolutionPreset resolution;
}
