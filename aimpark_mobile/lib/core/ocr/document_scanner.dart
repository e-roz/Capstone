import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'document_check.dart';
import 'ocr_payload.dart';

/// A photo, what text recognition read from it, and whether that is good enough.
class CapturedDocument {
  const CapturedDocument({
    required this.file,
    required this.payload,
    required this.issue,
  });

  final File file;

  /// Null when recognition failed outright.
  final OcrPayload? payload;

  /// What is wrong with this photo, or null when nothing is.
  ///
  /// Decided at capture rather than at upload. The photo used to be accepted on
  /// the sole basis that a file existed, so a black frame or a page of any text
  /// at all continued happily through the remaining steps and only came back —
  /// if at all — after four photographs had been uploaded together.
  final DocumentIssue? issue;

  bool get isUsable => issue == null;
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

  /// Reads [file] and returns the lines, boxes and verdict for [type].
  ///
  /// Never throws for an unreadable photo: recognition failure comes back as a
  /// null payload carrying [DocumentIssue.noText], because the caller decides
  /// what to do about it and this layer only reports.
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

      final payload = OcrPayload(
        documentType: type,
        imageWidth: size.width.round(),
        imageHeight: size.height.round(),
        lines: lines,
      );

      return CapturedDocument(
        file: file,
        payload: payload,
        issue: checkDocument(payload, type),
      );
    } catch (_) {
      // Recognition itself failing is indistinguishable, from here, from a photo
      // with nothing on it — and calls for the same response.
      return CapturedDocument(
        file: file,
        payload: null,
        issue: DocumentIssue.noText,
      );
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
