using System.Globalization;
using System.Text;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Compares a person's name as it appears on two different documents.
    /// </summary>
    /// <remarks>
    /// This is the hard part of the comparison work, not the OCR. The same person
    /// is printed as "REYES, JEAN ZYRIL" on a licence and "Jean Zyril Reyes" on a
    /// school form, and either may carry a middle name the other omits. String
    /// equality rejects real applicants all day.
    ///
    /// Only ever applied to documents that both belong to the applicant. The owner
    /// name on an Official Receipt is deliberately never compared — campus users
    /// commonly drive vehicles registered to family, so a mismatch there is expected
    /// and means nothing.
    /// </remarks>
    public static class NameMatching
    {
        // Generational suffixes appear on one document and not the other often
        // enough that treating them as part of the name causes false mismatches.
        private static readonly HashSet<string> Suffixes = new(StringComparer.OrdinalIgnoreCase)
        {
            "JR", "SR", "II", "III", "IV", "V"
        };

        /// <summary>
        /// Splits a name into comparable parts: uppercase, unaccented, punctuation
        /// and suffixes removed.
        /// </summary>
        public static List<string> Tokenize(string? name)
        {
            if (string.IsNullOrWhiteSpace(name))
                return [];

            var stripped = RemoveDiacritics(name);

            var tokens = new List<string>();
            foreach (var raw in stripped.Split(
                         [' ', ',', '.', '\t', '\n', '\r'],
                         StringSplitOptions.RemoveEmptyEntries))
            {
                var token = new string(raw.Where(char.IsLetter).ToArray()).ToUpperInvariant();

                if (token.Length == 0 || Suffixes.Contains(token))
                    continue;

                tokens.Add(token);
            }

            return tokens;
        }

        /// <summary>
        /// True when two names plausibly describe the same person.
        /// </summary>
        /// <remarks>
        /// Word order is ignored, because the two documents disagree about it by
        /// convention. The shorter name must be accounted for within the longer one:
        /// a form giving only "Jean Reyes" matches a licence reading "REYES, JEAN
        /// ZYRIL", while a genuinely different name does not.
        ///
        /// A single letter is treated as an initial and matches any word beginning
        /// with it, since one document routinely abbreviates the middle name the
        /// other spells out. Longer words allow one character of difference, which
        /// covers an OCR slip without letting unrelated names through.
        /// </remarks>
        public static bool IsProbableMatch(string? a, string? b)
        {
            var left = Tokenize(a);
            var right = Tokenize(b);

            if (left.Count == 0 || right.Count == 0)
                return false;

            var (shorter, longer) = left.Count <= right.Count ? (left, right) : (right, left);

            // A lone word is not enough to claim two people are the same.
            if (shorter.Count < 2)
                return false;

            var available = new List<string>(longer);

            foreach (var token in shorter)
            {
                var index = available.FindIndex(candidate => TokensAgree(token, candidate));
                if (index < 0)
                    return false;

                available.RemoveAt(index);
            }

            return true;
        }

        private static bool TokensAgree(string a, string b)
        {
            if (a.Length == 1 || b.Length == 1)
                return a[0] == b[0];

            if (a == b)
                return true;

            // Tolerate a single OCR slip, but only once the word is long enough that
            // one edit cannot turn it into a different name.
            return Math.Min(a.Length, b.Length) >= 4
                   && FuzzyText.EditDistance(a, b) <= 1;
        }

        private static string RemoveDiacritics(string value)
        {
            var normalized = value.Normalize(NormalizationForm.FormD);
            var builder = new StringBuilder(normalized.Length);

            foreach (var c in normalized)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark)
                    builder.Append(c);
            }

            return builder.ToString().Normalize(NormalizationForm.FormC);
        }
    }
}
