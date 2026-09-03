namespace AimPark.API.Helpers
{
    /// <summary>
    /// One spelling for a card UID, so the reader and the admin panel cannot
    /// disagree about what "the same card" means.
    /// </summary>
    /// <remarks>
    /// A tag lookup is a string comparison, which makes UID formatting a
    /// correctness problem rather than a cosmetic one: <c>04a2b3</c>,
    /// <c>04:A2:B3</c> and <c>04 A2 B3</c> are the same physical card and three
    /// different rows as far as the database is concerned. Readers, libraries
    /// and printed labels all disagree about separators and case, so every tag
    /// entering the system is squeezed into one shape here — uppercase hex, no
    /// separators — instead of trusting each caller to remember.
    /// </remarks>
    public static class RfidTag
    {
        /// <summary>Strips separators and uppercases. Returns "" for nothing usable.</summary>
        public static string Normalize(string? raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return string.Empty;

            var chars = new List<char>(raw.Length);
            foreach (var c in raw)
            {
                // Separators people and libraries insert: colons, dashes,
                // spaces. Dropped rather than rejected — they carry no meaning.
                if (c is ':' or '-' or ' ' or '\t' or '_') continue;
                chars.Add(char.ToUpperInvariant(c));
            }

            return new string(chars.ToArray());
        }

        /// <summary>
        /// A normalized UID that could plausibly have come off a card: hex, and
        /// long enough to be a real UID rather than a stray keystroke.
        /// </summary>
        /// <remarks>
        /// MIFARE UIDs are 4, 7 or 10 bytes — 8, 14 or 20 hex characters. The
        /// range is kept loose on purpose so an unusual card is not refused at
        /// the enrollment desk; this only catches obvious rubbish.
        /// </remarks>
        public static bool LooksValid(string normalized) =>
            normalized.Length is >= 6 and <= 32
            && normalized.All(c => c is >= '0' and <= '9' or >= 'A' and <= 'F');
    }
}
