import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'ocr_payload.dart';

/// A photo together with what text recognition read from it.
class CapturedDocument {
  const CapturedDocument({required this.file, required this.payload});

  final File file;

  /// Null when recognition failed outright. The photo is still submitted — the
  /// server treats a missing payload as "nothing was read" and the user types
  /// the values on the confirmation screen, rather than being blocked over a
  /// detail they cannot influence.
  final OcrPayload? payload;
}

/// Runs on-device text recognition over a captured document photo.
///
/// Kept out of the widget layer so the same scanner serves the registration
/// flow and the debug screen, and so a single recogniser instance is reused —
/// constructing one per photo reloads the model each time.
class DocumentScanner {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  /// Reads [file] and returns the lines and boxes for [type].
  ///
  /// Never throws for an unreadable photo: recognition failure comes back as a
  /// null payload on the result, because the flow must stay submittable.
  Future<CapturedDocument> scan(File file, ScanDocumentType type) async {
    try {
      final size = await _decodedSize(file);
      final recognised = await _recognizer.processImage(
        InputImage.fromFilePath(file.path),
      );

      final lines = <OcrLine>[];
      for (final block in recognised.blocks) {
        for (final line in block.lines) {
          final box = line.boundingBox;
          lines.add(
            OcrLine(
              text: line.text,
              x: box.left.round(),
              y: box.top.round(),
              width: box.width.round(),
              height: box.height.round(),
              // Android reports a per-line confidence; iOS does not. Substituting
              // zero would drag the page average under the server's blur
              // threshold and send a perfectly sharp photo back for a retake, so
              // a missing value is treated as "no evidence of blur". The effect
              // is that blur detection is Android-only, which matches the
              // deliverable being an APK.
              confidence: line.confidence ?? 1.0,
            ),
          );
        }
      }

      return CapturedDocument(
        file: file,
        payload: OcrPayload(
          documentType: type,
          imageWidth: size.width.round(),
          imageHeight: size.height.round(),
          lines: lines,
        ),
      );
    } catch (_) {
      return CapturedDocument(file: file, payload: null);
    }
  }

  /// Pixel size of the image as decoded, which is the space the boxes are
  /// measured in.
  Future<ui.Size> _decodedSize(File file) async {
    final decoded = await ui.instantiateImageCodec(await file.readAsBytes());
    final frame = await decoded.getNextFrame();
    final size = ui.Size(
      frame.image.width.toDouble(),
      frame.image.height.toDouble(),
    );
    frame.image.dispose();
    decoded.dispose();
    return size;
  }

  Future<void> dispose() => _recognizer.close();
}
