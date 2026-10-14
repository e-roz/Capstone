namespace AimPark.API.Helpers
{
    /// <summary>
    /// Where each bay sits, so allocation can rank by distance from the gate a
    /// vehicle tapped at.
    /// </summary>
    /// <remarks>
    /// The lot is two columns of nine facing each other across one drive lane,
    /// with Gate 1 at the top end and Gate 2 at the bottom (see
    /// <c>ParkingSlotSeed</c> and the admin parking map). A bay's distance from
    /// a gate is how many rows separate them; the two columns are the same
    /// distance for a given row. The layout is fixed, so it lives here rather
    /// than in the database.
    /// </remarks>
    public static class LotLayout
    {
        public const int Rows = 9;

        /// <summary>Row 1 is at Gate 1, row 9 at Gate 2.</summary>
        private static readonly Dictionary<string, int> RowOf = new(StringComparer.OrdinalIgnoreCase)
        {
            // Left column, top to bottom
            ["C1"] = 1, ["C2"] = 2, ["C3"] = 3,
            ["M1"] = 4, ["M2"] = 5, ["M3"] = 6, ["M4"] = 7, ["M5"] = 8, ["M6"] = 9,

            // Right column, top to bottom
            ["M12"] = 1, ["M11"] = 2, ["M10"] = 3, ["M9"] = 4, ["M8"] = 5, ["M7"] = 6,
            ["C6"] = 7, ["C5"] = 8, ["C4"] = 9,
        };

        /// <summary>
        /// Rows between the gate and the bay: 0 for the bays right at the gate.
        /// A bay not on the map, or an unknown gate, sorts after every mapped one.
        /// </summary>
        public static int DistanceFrom(int gate, string slotCode)
        {
            if (!RowOf.TryGetValue(slotCode, out var row))
                return int.MaxValue;

            return gate switch
            {
                1 => row - 1,
                2 => Rows - row,
                _ => int.MaxValue,
            };
        }

        /// <summary>
        /// The number in a slot code, for ordering bays the same distance away.
        /// "M7" is 7, so it comes before "M10"; compared as text it would not.
        /// </summary>
        public static int NumberOf(string slotCode)
        {
            var digits = new string(slotCode.Where(char.IsDigit).ToArray());
            return int.TryParse(digits, out var n) ? n : int.MaxValue;
        }
    }
}
