import 'dart:convert';
import 'dart:typed_data';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Builds and hands the administrator a CSV file.
///
/// The document lists "Generated Reports — view and **export** summarized logs
/// for monitoring, auditing and documentation". Everything exported here is
/// already on screen, so this is a client-side download rather than a report
/// endpoint: no new API surface, and the file always matches exactly what the
/// administrator was looking at when they pressed the button.
///
/// The panel is web-only (see `pubspec.yaml`), so `package:web` can be imported
/// directly without a conditional-import shim.
class CsvExport {
  CsvExport._();

  /// Escapes one cell per RFC 4180: wrap in quotes when the value contains a
  /// comma, a quote or a newline, and double any quote inside.
  static String _cell(Object? value) {
    final s = value?.toString() ?? '';
    if (!s.contains(RegExp(r'[",\n\r]'))) return s;
    return '"${s.replaceAll('"', '""')}"';
  }

  /// Renders [rows] under [headers] as CSV text.
  static String build({
    required List<String> headers,
    required List<List<Object?>> rows,
  }) {
    final buffer = StringBuffer()..writeln(headers.map(_cell).join(','));
    for (final row in rows) {
      buffer.writeln(row.map(_cell).join(','));
    }
    return buffer.toString();
  }

  /// Triggers a browser download of [csv] as [fileName].
  ///
  /// The UTF-8 BOM is deliberate: without it Excel on a Windows machine — which
  /// is what the administration office runs — reads `₱` and any `ñ` in a name as
  /// mojibake.
  static void download(String fileName, String csv) {
    final bytes = Uint8List.fromList(utf8.encode('﻿$csv'));
    final blob = web.Blob(
      [bytes.toJS].toJS,
      web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
    );
    final url = web.URL.createObjectURL(blob);

    final anchor = web.document.createElement('a') as web.HTMLAnchorElement
      ..href = url
      ..download = fileName;
    anchor.click();

    web.URL.revokeObjectURL(url);
  }

  /// Build and download in one step.
  static void save({
    required String fileName,
    required List<String> headers,
    required List<List<Object?>> rows,
  }) =>
      download(fileName, build(headers: headers, rows: rows));
}
