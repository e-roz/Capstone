import 'dart:async';
import 'dart:convert';
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

  /// Opens an empty tab that a PDF will be shown in once it is ready.
  ///
  /// This must run straight from the click, before any `await`: a browser only
  /// lets a page open a tab while it is handling the user's click, and blocks
  /// it as a pop-up once the click is over. So the tab is opened first and
  /// filled in later by [showPdfInTab]. Returns null if the browser blocked it.
  static web.Window? openBlankTab(String waitingText) {
    final tab = web.window.open('', '_blank');
    if (tab == null) return null;
    tab.document.title = waitingText;
    tab.document.body?.textContent = waitingText;
    return tab;
  }

  /// Shows [bytes] as a PDF in [tab], with a Print and a Save button on top.
  ///
  /// The page is our own small HTML page with the PDF inside an iframe, not
  /// the bare PDF: a bare PDF opened from memory (a `blob:` address) is saved
  /// under a random name, while our Save button keeps [fileName], which holds
  /// the report number.
  ///
  /// A `blob:` address belongs to the page that made it and dies with it. If
  /// this panel made the PDF's address, closing or reloading the panel would
  /// break Save and Print in the report tab. So the PDF bytes travel inside the
  /// report page (as base64 text) and the report page makes its own address
  /// from them: the report tab then owns its copy and keeps working on its own.
  static void showPdfInTab(
    web.Window tab,
    Uint8List bytes, {
    required String fileName,
    required String title,
  }) {
    final page = _pdfViewerPage(pdfBase64: base64Encode(bytes), fileName: fileName, title: title);
    final pageUrl = web.URL.createObjectURL(
      web.Blob([page.toJS].toJS, web.BlobPropertyBag(type: 'text/html')),
    );

    tab.location.href = pageUrl;
  }

  static String _pdfViewerPage({
    required String pdfBase64,
    required String fileName,
    required String title,
  }) {
    // Text from the server goes into HTML, so it is escaped first.
    final t = const HtmlEscape().convert(title);
    final f = const HtmlEscape().convert(fileName);

    return '''
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>$t</title>
<style>
  html, body { margin: 0; height: 100%; font-family: system-ui, sans-serif; }
  body { display: flex; flex-direction: column; background: #f4f4f5; }
  header { display: flex; align-items: center; gap: 8px; padding: 10px 16px;
           background: #fff; border-bottom: 1px solid #e4e4e7; }
  h1 { flex: 1; margin: 0; font-size: 16px; font-weight: 600; color: #18181b; }
  button, a { font: inherit; font-size: 14px; padding: 8px 16px; border-radius: 8px;
              cursor: pointer; text-decoration: none; }
  #print { background: #fff; color: #18181b; border: 1px solid #d4d4d8; }
  #save { background: #18181b; color: #fff; border: 1px solid #18181b; }
  iframe { flex: 1; width: 100%; border: 0; }
</style>
</head>
<body>
<header>
  <h1>$t</h1>
  <button id="print" type="button">Print</button>
  <a id="save" download="$f">Save to computer</a>
</header>
<iframe id="doc" title="$t"></iframe>
<script>
  // Turn the base64 text back into bytes and give them an address that
  // belongs to this tab, so it outlives the admin panel that opened it.
  var text = atob('$pdfBase64');
  var bytes = new Uint8Array(text.length);
  for (var i = 0; i < text.length; i++) bytes[i] = text.charCodeAt(i);
  var url = URL.createObjectURL(new Blob([bytes], { type: 'application/pdf' }));
  document.getElementById('doc').src = url;
  document.getElementById('save').href = url;

  document.getElementById('print').addEventListener('click', function () {
    document.getElementById('doc').contentWindow.print();
  });
</script>
</body>
</html>
''';
  }
}
