namespace AimPark.API.Helpers
{
    /// <summary>
    /// Tolerant text matching for values coming out of OCR.
    /// </summary>
    public static class FuzzyText
    {
        /// <summary>
        /// Characters OCR routinely confuses, mapped back to their digit.
        /// </summary>
        /// <remarks>
        /// Safe only where the field is known in advance to be numeric — which the
        /// label anchor establishes before this ever runs. In testing this repaired
        /// "o7/11/2025" to "07/11/2025".
        /// </remarks>
        private static readonly Dictionary<char, char> LookalikeDigits = new()
        {
            ['O'] = '0', ['o'] = '0', ['Q'] = '0', ['D'] = '0',
            ['I'] = '1', ['l'] = '1', ['|'] = '1',
            ['Z'] = '2',
            ['S'] = '5',
            ['G'] = '6',
            ['T'] = '7',
            ['B'] = '8',
        };

        /// <summary>
        /// Levenshtein distance — the number of single-character edits between two
        /// strings.
        /// </summary>
        public static int EditDistance(string a, string b)
        {
            if (string.IsNullOrEmpty(a)) return b?.Length ?? 0;
            if (string.IsNullOrEmpty(b)) return a.Length;

            var previous = new int[b.Length + 1];
            var current = new int[b.Length + 1];

            for (var j = 0; j <= b.Length; j++)
                previous[j] = j;

            for (var i = 1; i <= a.Length; i++)
            {
                current[0] = i;
                for (var j = 1; j <= b.Length; j++)
                {
                    var cost = a[i - 1] == b[j - 1] ? 0 : 1;
                    current[j] = Math.Min(
                        Math.Min(current[j - 1] + 1, previous[j] + 1),
                        previous[j - 1] + cost);
                }

                (previous, current) = (current, previous);
            }

            return previous[b.Length];
        }

        /// <summary>
        /// Finds a label inside a line, allowing for OCR mangling it.
        /// </summary>
        /// <remarks>
        /// Labels come back damaged — "Plale No" for "Plate No", "vaIid until" for
        /// "valid until" — so requiring an exact match would lose the anchor that
        /// makes extraction safe in the first place.
        ///
        /// Returns the index just past the label, or -1 when it is not present.
        ///
        /// Pass -1 for <paramref name="tolerance"/> to scale it with the label's
        /// length. A fixed allowance of two edits is fine for "Expiration Date" but
        /// catastrophic for "SY", where it would match any two characters on the
        /// page — and on a receipt a loose four-letter match turns "Rate" into
        /// "Date".
        /// </remarks>
        public static int IndexAfterLabel(string line, string label, int tolerance = -1)
        {
            if (string.IsNullOrWhiteSpace(line) || string.IsNullOrWhiteSpace(label))
                return -1;

            if (tolerance < 0)
                tolerance = ToleranceFor(label);

            var haystack = line.ToLowerInvariant();
            var needle = label.ToLowerInvariant();

            if (needle.Length > haystack.Length)
                return -1;

            var best = -1;
            var bestDistance = tolerance + 1;

            for (var start = 0; start + needle.Length <= haystack.Length; start++)
            {
                var window = haystack.Substring(start, needle.Length);
                var distance = EditDistance(window, needle);

                if (distance < bestDistance)
                {
                    bestDistance = distance;
                    best = start + needle.Length;

                    if (distance == 0)
                        break;
                }
            }

            return bestDistance <= tolerance ? best : -1;
        }

        /// <summary>
        /// How far a label may be mangled before it stops counting as present.
        /// </summary>
        /// <remarks>
        /// Scales with length. Two edits is nothing on "Expiration Date" but is half
        /// the word on "SY", and on a real form it was enough to make "Student
        /// Information" match the label "Student No" — which then sent the rule
        /// looking for a value in the wrong place entirely.
        /// </remarks>
        public static int ToleranceFor(string label) => label.Length switch
        {
            <= 4 => 0,
            <= 10 => 1,
            _ => 2
        };

        /// <summary>
        /// How badly mangled the best occurrence of a label is within a line, or
        /// <see cref="int.MaxValue"/> when it does not appear at all.
        /// </summary>
        /// <remarks>
        /// Lets a caller compare candidate lines and take the closest, rather than
        /// settling for whichever happened to come first.
        /// </remarks>
        public static int LabelDistance(string line, string label)
        {
            if (string.IsNullOrWhiteSpace(line) || string.IsNullOrWhiteSpace(label))
                return int.MaxValue;

            var haystack = line.ToLowerInvariant();
            var needle = label.ToLowerInvariant();

            if (needle.Length > haystack.Length)
                return int.MaxValue;

            var best = int.MaxValue;
            for (var start = 0; start + needle.Length <= haystack.Length; start++)
            {
                var distance = EditDistance(haystack.Substring(start, needle.Length), needle);
                if (distance < best)
                    best = distance;

                if (best == 0)
                    break;
            }

            return best <= ToleranceFor(label) ? best : int.MaxValue;
        }

        /// <summary>
        /// Maps lookalike characters back to digits in a value already known to be
        /// numeric.
        /// </summary>
        public static string RepairDigits(string? value)
        {
            if (string.IsNullOrEmpty(value))
                return string.Empty;

            return new string(value
                .Select(c => LookalikeDigits.TryGetValue(c, out var digit) ? digit : c)
                .ToArray());
        }

        /// <summary>
        /// Strips the punctuation OCR sprinkles around a value it has just read.
        /// </summary>
        public static string TrimValue(string? value)
            => value?.Trim().Trim(':', '.', ',', '-', '—', '/', ' ') ?? string.Empty;
    }
}
