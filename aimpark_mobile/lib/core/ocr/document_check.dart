import 'ocr_payload.dart';

/// Why a captured document is not good enough to continue with.
///
/// Mirrors the C# `ScanFailureReason`. The server remains the authority — a
/// modified client cannot talk its way past it — but repeating the check here
/// is what makes it useful: the verdict arrives while the document is still in
/// the user's hand, rather than after four photographs and an upload.
enum DocumentIssue {
  /// Almost no text. A dark frame, a lens cap, a photo of a wall.
  noText,

  /// Most lines are rotated; the phone was held the wrong way round.
  sideways,

  /// Plenty of text, all of it read badly.
  blurry,

  /// Readable, but not the document it was submitted as.
  wrongDocument,
}

/// What to tell the user, and what to do about it.
///
/// Written here rather than reusing the server's wording because these fire
/// before anything is uploaded, and the phrasing can name the frame and the
/// light — things the user can still change.
String documentIssueMessage(DocumentIssue issue, String label) =>
    switch (issue) {
      DocumentIssue.noText =>
        "We couldn't find any text on this photo. Make sure the $label fills "
            'the frame and the light is good.',
      DocumentIssue.sideways =>
        'Turn your phone so the $label reads upright, then take it again.',
      DocumentIssue.blurry =>
        'Too blurry to read. Hold steady, get a little closer, and try again.',
      DocumentIssue.wrongDocument =>
        "This doesn't look like the $label. Check you photographed the right "
            'document, and that all of it is inside the frame.',
    };

/// Printing that a genuine copy of each document always carries.
///
/// Two document types are deliberately absent. A school ID has no national
/// layout and is never parsed — the reviewer looks at it by eye. A plate photo
/// carries no labels at all; it is checked instead by whether the plate the
/// receipt named turns up on it, which only the server can do.
///
/// Kept in step with `DocumentLandmarks.cs` by hand. The server's copy is the
/// one that decides; this one only decides how soon the user hears about it, so
/// the two drifting apart costs a late message rather than a wrong verdict.
const _landmarks = <ScanDocumentType, List<String>>{
  ScanDocumentType.raf: [
    'Student No',
    'SY & Term',
    'Year Level',
    'CHARGES for',
    'Program',
  ],
  ScanDocumentType.license: [
    "DRIVER'S LICENSE",
    'Expiration Date',
    'Republika ng Pilipinas',
    'Nationality',
    'License No',
  ],
  ScanDocumentType.officialReceipt: [
    'OFFICIAL RECEIPT',
    'LAND TRANSPORTATION',
    'Plate No',
    'MV File No',
    'Amount Paid',
  ],
};

/// Below this, "we found some text" is not a claim worth making.
const _minimumUsableLines = 5;

/// A page whose lines average worse than this was legible to the camera but not
/// to the reader.
const _blurryConfidence = 0.55;

/// Past this share of rotated lines the page itself is sideways.
const _sidewaysShare = 0.5;

/// How many landmarks must be found before a document is accepted as genuine.
const _requiredLandmarks = 2;

/// True when a line's box is taller than it is wide.
///
/// The OR and the CR are printed on one sheet with the CR at 90°, so rotated
/// text is how the CR shows up — tall and narrow — and dropping it is what stops
/// its wording being searched for receipt landmarks it does not carry.
bool _isRotated(OcrLine line) => line.height > line.width;

/// What is wrong with this reading, or null when nothing is.
///
/// Readability is settled before identity, deliberately. A page too dark to read
/// cannot be identified either, and telling someone their receipt is the wrong
/// document when it is merely underexposed sends them looking for paperwork they
/// are already holding.
DocumentIssue? checkDocument(OcrPayload? payload, ScanDocumentType type) {
  if (payload == null || payload.lines.length < _minimumUsableLines) {
    return DocumentIssue.noText;
  }

  final rotated = payload.lines.where(_isRotated).length;
  if (rotated / payload.lines.length > _sidewaysShare) {
    return DocumentIssue.sideways;
  }

  final upright = payload.lines.where((l) => !_isRotated(l)).toList();
  if (upright.length < _minimumUsableLines) return DocumentIssue.noText;

  final meanConfidence =
      upright.fold<double>(0, (sum, l) => sum + l.confidence) / upright.length;
  if (meanConfidence < _blurryConfidence) return DocumentIssue.blurry;

  final expected = _landmarks[type];
  if (expected == null) return null;

  final hits = expected.where((l) => _appearsIn(upright, l)).length;
  return hits >= _requiredLandmarks ? null : DocumentIssue.wrongDocument;
}

bool _appearsIn(List<OcrLine> lines, String label) =>
    lines.any((line) => _containsLabel(line.text, label));

/// How far a label may be mangled before it stops counting as present.
///
/// Scales with length: two edits is nothing on "Expiration Date" but is half the
/// word on "SY".
int _toleranceFor(String label) => switch (label.length) {
      <= 4 => 0,
      <= 10 => 1,
      _ => 2,
    };

/// Whether [label] appears anywhere in [text], allowing for OCR damage.
bool _containsLabel(String text, String label) {
  if (text.isEmpty || label.isEmpty) return false;

  final haystack = text.toLowerCase();
  final needle = label.toLowerCase();
  if (needle.length > haystack.length) return false;

  final tolerance = _toleranceFor(label);

  for (var start = 0; start + needle.length <= haystack.length; start++) {
    final window = haystack.substring(start, start + needle.length);
    if (_editDistance(window, needle) <= tolerance) return true;
  }

  return false;
}

/// Levenshtein distance, two rows at a time.
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 1; i <= a.length; i++) {
    current[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      final deletion = previous[j] + 1;
      final insertion = current[j - 1] + 1;
      final substitution = previous[j - 1] + cost;
      current[j] = deletion < insertion
          ? (deletion < substitution ? deletion : substitution)
          : (insertion < substitution ? insertion : substitution);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[b.length];
}
