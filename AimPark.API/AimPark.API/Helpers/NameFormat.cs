namespace AimPark.API.Helpers
{
    /// <summary>
    /// Assembles a name in the "Last, First Middle" shape — how the RAF's three
    /// separate cells and a driver's licence's single printed line both end up
    /// looking, once put together. Shared so the two things being compared are
    /// guaranteed to be built the same way.
    /// </summary>
    public static class NameFormat
    {
        /// <summary>
        /// Joins three independently-read parts. Missing parts are skipped
        /// cleanly — no stray comma or double space.
        /// </summary>
        public static string? LastFirstMiddle(string? last, string? first, string? middle)
        {
            var firstMiddle = string.Join(
                ' ',
                new[] { first, middle }.Where(p => !string.IsNullOrWhiteSpace(p)));

            var trimmedLast = last?.Trim();

            if (string.IsNullOrWhiteSpace(trimmedLast))
                return firstMiddle.Length == 0 ? null : firstMiddle;

            return firstMiddle.Length == 0 ? trimmedLast : $"{trimmedLast}, {firstMiddle}";
        }

        /// <summary>
        /// Reshapes a freely typed name — the account's own <c>FullName</c> —
        /// into the same "Last, First Middle" form.
        /// </summary>
        /// <remarks>
        /// Only used for faculty and staff, who have no RAF to read separate
        /// name parts from. A single typed string carries no structure — there
        /// is no way to know which word is the surname — so the last word typed
        /// is treated as the last name, which matches how a "Full Name" field is
        /// ordinarily filled in. Imperfect for a name that does not follow that
        /// convention; accepted as the best available signal from free text.
        /// </remarks>
        public static string? FromTypedFullName(string? typed)
        {
            if (string.IsNullOrWhiteSpace(typed))
                return null;

            var words = typed.Split(
                ' ',
                StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);

            return words.Length switch
            {
                0 => null,
                1 => words[0],
                _ => $"{words[^1]}, {string.Join(' ', words[..^1])}"
            };
        }
    }
}
