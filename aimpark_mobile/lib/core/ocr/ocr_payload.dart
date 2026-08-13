import 'dart:convert';

/// Which document a payload describes.
///
/// The wire names must match the C# `DocumentType` enum member names exactly —
/// the server deserialises them by name, not by ordinal, so reordering this
/// enum is safe but renaming a [wireName] is not.
enum ScanDocumentType {
  /// School registration/assessment form — students.
  raf('Raf'),

  /// School-issued ID — faculty and staff send this instead of a RAF.
  schoolId('SchoolId'),

  license('License'),
  officialReceipt('OfficialReceipt'),
  platePhoto('PlatePhoto');

  const ScanDocumentType(this.wireName);

  final String wireName;
}

/// One recognised line of text and the box it occupied on the page.
///
/// Line level, not block or word: blocks flatten a whole paragraph into one
/// rectangle and lose the geometry the server needs to read a value outward
/// from its label, while words explode the payload for nothing.
class OcrLine {
  const OcrLine({
    required this.text,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.confidence,
  });

  final String text;
  final int x;
  final int y;
  final int width;
  final int height;

  /// 0–1.
  final double confidence;

  /// Keys are the C# property names, matched case-insensitively by the server.
  Map<String, dynamic> toJson() => {
    'text': text,
    'x': x,
    'y': y,
    'w': width,
    'h': height,
    'confidence': confidence,
  };
}

/// What text recognition returned for one document.
///
/// Travels in the same multipart request as the image it describes, so the
/// stored photo and the reading of it can never drift apart.
class OcrPayload {
  const OcrPayload({
    required this.documentType,
    required this.imageWidth,
    required this.imageHeight,
    required this.lines,
  });

  final ScanDocumentType documentType;

  /// Pixel size of the image the boxes were measured against. Without it the
  /// server would be reasoning in one handset's pixels and every spatial
  /// comparison would break on a phone with a different camera.
  final int imageWidth;
  final int imageHeight;

  final List<OcrLine> lines;

  Map<String, dynamic> toJson() => {
    'documentType': documentType.wireName,
    'imageWidth': imageWidth,
    'imageHeight': imageHeight,
    'lines': lines.map((l) => l.toJson()).toList(),
  };

  String toJsonString() => jsonEncode(toJson());

  /// True when every box sits inside the image bounds.
  ///
  /// The boxes and the dimensions come from two different decoders, and a photo
  /// carrying EXIF rotation is the case where they could disagree — one
  /// applying the rotation and the other not. That would silently transpose the
  /// page and make every anchor rule miss. Surfaced on the debug screen rather
  /// than corrected here, because a guess at which decoder was right would be
  /// worse than seeing the mismatch during testing.
  bool get boxesFitImage => lines.every(
    (l) =>
        l.x >= 0 &&
        l.y >= 0 &&
        l.x + l.width <= imageWidth &&
        l.y + l.height <= imageHeight,
  );
}
