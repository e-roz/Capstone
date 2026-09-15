using AimPark.API.DTOs;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a name already trusted — read from the RAF, or typed at signup —
    /// turns up on the licence, rather than independently reading a name off the
    /// licence and comparing two guesses against each other.
    /// </summary>
    /// <remarks>
    /// The same trick the plate photo used to play, before it was removed:
    /// "does the value we already expect appear here" is a far easier question
    /// than "what does this say", and answering it never depends on correctly
    /// locating or parsing the licence's own name caption — which is exactly
    /// what was failing. The caption reads badly ("Lest Narne. First flame.
    /// Middie Name" for "Last Name, First Name, Middle Name"); the printed name
    /// itself, one line below it, reads far better in practice.
    /// </remarks>
    public static class NameLocator
    {
        /// <summary>
        /// True once a line looks close enough to <paramref name="expectedName"/>.
        /// Null when there was nothing to check against — no expected name, or
        /// no licence lines at all — which is what keeps a submission in manual
        /// review rather than failing it outright. False means the search
        /// genuinely came up empty.
        /// </summary>
        public static bool? AppearsIn(IReadOnlyList<OcrLineDto> lines, string? expectedName)
        {
            var expected = Normalize(expectedName);
            if (expected.Length == 0 || lines.Count == 0)
                return null;

            var tolerance = ToleranceFor(expected.Length);

            foreach (var line in lines)
            {
                var candidate = Normalize(line.Text);
                if (candidate.Length == 0)
                    continue;

                if (FuzzyText.EditDistance(candidate, expected) <= tolerance)
                    return true;
            }

            return false;
        }

        /// <summary>
        /// How many characters a full name may be mangled by and still count as
        /// present. Scales with length rather than using
        /// <see cref="FuzzyText.ToleranceFor"/>'s fixed two-edit cap — right for
        /// a short label, but exactly the cap that let a ~35-character caption
        /// go unmatched here. A whole name needs more slack than that to survive
        /// ordinary OCR noise.
        /// </summary>
        private static int ToleranceFor(int length)
            => Math.Clamp((int)Math.Ceiling(length * 0.15), 2, 6);

        /// <summary>
        /// Uppercase, accents stripped, only letters/digits/spaces kept.
        /// </summary>
        /// <remarks>
        /// Punctuation is dropped from both sides rather than compared — the
        /// expected string always carries exactly one comma by construction
        /// (<see cref="NameFormat.LastFirstMiddle"/>), but what the licence's
        /// comma actually OCRs as is not reliable, so comparing it would only
        /// ever cost a false negative, never catch a real mismatch.
        /// </remarks>
        private static string Normalize(string? value)
        {
            if (string.IsNullOrWhiteSpace(value))
                return string.Empty;

            var stripped = NameMatching.RemoveDiacritics(value);
            var kept = stripped.Where(c => char.IsLetterOrDigit(c) || c == ' ').ToArray();
            return new string(kept).ToUpperInvariant().Trim();
        }
    }
}
