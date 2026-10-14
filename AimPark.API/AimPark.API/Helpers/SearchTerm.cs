namespace AimPark.API.Helpers
{
    /// <summary>
    /// What an admin typed in the search box, spelled the ways the data is held.
    /// </summary>
    /// <remarks>
    /// One box has to find a name, a plate and a card. Plates are stored
    /// uppercase with no spaces or dashes and card UIDs as uppercase hex with
    /// no separators (see <see cref="IdentifierNormalizer"/> and
    /// <see cref="RfidTag"/>), so a typed "ncd 4417" or "04:a1:22" would miss
    /// every row if it were compared as typed.
    /// </remarks>
    public sealed record SearchTerm(string Text, string Plate, string Tag)
    {
        // Two letters is enough to find a name; fewer than three characters of
        // a plate, or four of a card, would match half the table.
        private const int MinText = 2;
        private const int MinPlate = 3;
        private const int MinTag = 4;

        public bool UsableText => Text.Length >= MinText;
        public bool UsablePlate => Plate.Length >= MinPlate;

        /// <summary>Only when everything typed could be part of a card UID.</summary>
        public bool UsableTag => Tag.Length >= MinTag && Tag.All(Uri.IsHexDigit);

        public bool IsEmpty => !UsableText && !UsablePlate && !UsableTag;

        public static SearchTerm Parse(string? typed)
        {
            var text = (typed ?? string.Empty).Trim();
            return new SearchTerm(text, IdentifierNormalizer.NormalizePlate(text), RfidTag.Normalize(text));
        }
    }
}
