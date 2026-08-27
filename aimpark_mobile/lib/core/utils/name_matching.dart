/// Compares a person's name as it appears on two different documents.
///
/// A deliberate port of the server's `NameMatching` helper, kept rule-for-rule
/// identical. The point of running it on the phone is to warn someone *before*
/// they submit, and a warning the server would not have raised — or a silence
/// where the server will raise one — is worse than not warning at all. If one
/// side changes, change both.
///
/// The hard part is not reading the name, it is that the same person prints as
/// "REYES, JEAN ZYRIL" on a licence and "Jean Zyril Reyes" on a school form, and
/// either document may carry a middle name the other omits. String equality
/// rejects real applicants all day.
///
/// Only ever applied to two documents that both belong to the applicant. The
/// owner named on an Official Receipt is never compared — campus users commonly
/// drive vehicles registered to family, so a mismatch there means nothing.
library;

/// Generational suffixes turn up on one document and not the other often enough
/// that treating them as part of the name causes false mismatches.
const _suffixes = {'JR', 'SR', 'II', 'III', 'IV', 'V'};

/// Accented letters folded to their base form.
///
/// The server does this with Unicode normalisation, which Dart has no built-in
/// equivalent for, so the Latin-1 range is spelled out. Skipping it would not be
/// a cosmetic difference: letters-only filtering drops what it cannot fold, so
/// "Peña" would tokenise as PEA here and PENA on the server, and the phone would
/// report a name mismatch on a surname the server matches happily. Ñ alone
/// justifies the table on a Philippine campus.
const _foldedLetters = {
  'À': 'A', 'Á': 'A', 'Â': 'A', 'Ã': 'A', 'Ä': 'A', 'Å': 'A',
  'Ç': 'C',
  'È': 'E', 'É': 'E', 'Ê': 'E', 'Ë': 'E',
  'Ì': 'I', 'Í': 'I', 'Î': 'I', 'Ï': 'I',
  'Ñ': 'N',
  'Ò': 'O', 'Ó': 'O', 'Ô': 'O', 'Õ': 'O', 'Ö': 'O', 'Ø': 'O',
  'Ù': 'U', 'Ú': 'U', 'Û': 'U', 'Ü': 'U',
  'Ý': 'Y',
};

String _fold(String value) {
  final buffer = StringBuffer();
  for (final rune in value.toUpperCase().runes) {
    final char = String.fromCharCode(rune);
    buffer.write(_foldedLetters[char] ?? char);
  }
  return buffer.toString();
}

/// Splits a name into comparable parts: uppercase, unaccented, letters only,
/// suffixes gone.
List<String> tokenizeName(String? name) {
  if (name == null || name.trim().isEmpty) return const [];

  final tokens = <String>[];
  for (final raw in _fold(name).split(RegExp(r'[\s,.\t\n\r]+'))) {
    final token = raw.replaceAll(RegExp(r'[^A-Z]'), '');
    if (token.isEmpty || _suffixes.contains(token)) continue;
    tokens.add(token);
  }

  return tokens;
}

/// True when two names plausibly describe the same person.
///
/// Word order is ignored, because the two documents disagree about it by
/// convention. The shorter name must be accounted for within the longer one, so
/// a form giving only "Jean Reyes" matches a licence reading "REYES, JEAN ZYRIL"
/// while a genuinely different name does not.
///
/// A single letter is treated as an initial and matches any word starting with
/// it, since one document routinely abbreviates what the other spells out.
/// Longer words tolerate one character of difference, which covers an OCR slip
/// without letting unrelated names through.
bool isProbableNameMatch(String? a, String? b) {
  final left = tokenizeName(a);
  final right = tokenizeName(b);

  if (left.isEmpty || right.isEmpty) return false;

  final shorter = left.length <= right.length ? left : right;
  final longer = left.length <= right.length ? right : left;

  // A lone word is not enough to claim two people are the same.
  if (shorter.length < 2) return false;

  final available = [...longer];

  for (final token in shorter) {
    final index = available.indexWhere((c) => _tokensAgree(token, c));
    if (index < 0) return false;
    available.removeAt(index);
  }

  return true;
}

bool _tokensAgree(String a, String b) {
  if (a.length == 1 || b.length == 1) return a[0] == b[0];
  if (a == b) return true;

  // Tolerate a single OCR slip, but only once the word is long enough that one
  // edit cannot turn it into a different name.
  final shortest = a.length < b.length ? a.length : b.length;
  return shortest >= 4 && _editDistance(a, b) <= 1;
}

/// Levenshtein distance, two rows rather than a full matrix.
int _editDistance(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;

  var previous = List<int>.generate(b.length + 1, (i) => i);
  var current = List<int>.filled(b.length + 1, 0);

  for (var i = 0; i < a.length; i++) {
    current[0] = i + 1;
    for (var j = 0; j < b.length; j++) {
      final substitution = previous[j] + (a[i] == b[j] ? 0 : 1);
      final insertion = current[j] + 1;
      final deletion = previous[j + 1] + 1;
      current[j + 1] = substitution < insertion
          ? (substitution < deletion ? substitution : deletion)
          : (insertion < deletion ? insertion : deletion);
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  return previous[b.length];
}
