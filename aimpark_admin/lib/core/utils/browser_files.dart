import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

/// A file the administrator chose from their machine.
class PickedFile {
  const PickedFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;

  String get readableSize {
    if (bytes.length < 1024) return '${bytes.length} B';
    if (bytes.length < 1024 * 1024) {
      return '${(bytes.length / 1024).toStringAsFixed(0)} KB';
    }
    return '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

/// Reading a file from, and handing a file to, the browser.
///
/// The panel is web-only (see `pubspec.yaml`), so `package:web` is imported
/// directly and no file-picker dependency is needed — the same reasoning, and
/// the same Blob-and-anchor download, as `CsvExport`.
class BrowserFiles {
  BrowserFiles._();

  /// Opens the native file dialog and returns what was chosen.
  ///
  /// The returned future completes only when a file is actually selected: a
  /// browser fires no event for a cancelled dialog, so there is nothing to
  /// listen for. Callers must therefore not put the UI into a busy state
  /// *before* awaiting this — cancelling would strand it there. Set the busy
  /// flag once a file is in hand.
  static Future<PickedFile?> pick({String accept = '.json,application/json'}) {
    final completer = Completer<PickedFile?>();

    final input = web.document.createElement('input') as web.HTMLInputElement
      ..type = 'file'
      ..accept = accept;

    input.onChange.listen((_) {
      final files = input.files;
      if (files == null || files.length == 0) {
        if (!completer.isCompleted) completer.complete(null);
        return;
      }

      final file = files.item(0)!;
      final reader = web.FileReader();

      reader.onLoadEnd.listen((_) {
        if (completer.isCompleted) return;

        final result = reader.result;
        if (result == null) {
          completer.complete(null);
          return;
        }

        completer.complete(PickedFile(
          name: file.name,
          bytes: (result as JSArrayBuffer).toDart.asUint8List(),
        ));
      });

      // `FileReader` exposes no `onError` stream getter in package:web, so the
      // error event is subscribed to through the generic provider.
      web.EventStreamProviders.errorEvent.forTarget(reader).listen((_) {
        if (!completer.isCompleted) completer.complete(null);
      });

      reader.readAsArrayBuffer(file);
    });

    input.click();
    return completer.future;
  }

  /// Triggers a browser download of [bytes] as [fileName].
  static void download(
    String fileName,
    Uint8List bytes, {
    String mimeType = 'application/json',
  }) {
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: mimeType),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName;
    anchor.click();

    web.URL.revokeObjectURL(url);
  }
}
