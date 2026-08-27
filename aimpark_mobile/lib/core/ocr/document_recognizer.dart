import 'dart:io';

import '../camera/frame_recognizer.dart';
import 'document_scanner.dart';
import 'ocr_payload.dart';

/// Binds a [DocumentScanner] to one document type so it satisfies
/// [FrameRecognizer].
///
/// The scanner needs to know *which* document it is reading — that goes into
/// the payload the server matches its anchor rules against — but a recogniser
/// takes only a file. This is that adapter, and it is cheap: it holds a
/// reference to the shared scanner rather than a model of its own, so one
/// recogniser per capture costs nothing while the expensive `TextRecognizer`
/// stays alive across the whole flow.
class DocumentRecognizer implements FrameRecognizer<CapturedDocument> {
  const DocumentRecognizer(this.scanner, this.type);

  /// Owned by `documentScannerProvider`, not by this adapter.
  final DocumentScanner scanner;

  final ScanDocumentType type;

  @override
  String get busyMessage => 'Reading the document…';

  @override
  Future<CapturedDocument> recognize(File file) => scanner.scan(file, type);

  /// Deliberately a no-op. The adapter does not own the scanner, and closing a
  /// recogniser that is shared across four captures would leave the remaining
  /// three reading nothing.
  @override
  Future<void> dispose() async {}
}
