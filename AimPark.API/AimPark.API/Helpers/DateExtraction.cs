using System.Globalization;
using System.Text.RegularExpressions;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Pulls dates out of OCR text, in the formats these documents actually print.
    /// </summary>
    public static partial class DateExtraction
    {
        // Runs before matching, so "o7/11/2025" becomes "07/11/2025". Safe because
        // these patterns only ever run where a date is already expected.
        [GeneratedRegex(@"\b(\d{1,2})[/\-](\d{1,2})[/\-](\d{4})\b")]
        private static partial Regex FullDatePattern();

        [GeneratedRegex(@"\b(\d{4})[/\-](\d{1,2})[/\-](\d{1,2})\b")]
        private static partial Regex IsoDatePattern();

        [GeneratedRegex(@"\b(\d{1,2})[/\-](\d{4})\b")]
        private static partial Regex MonthYearPattern();

        /// <summary>
        /// First full date in the text, read as month-first then year-first.
        /// </summary>
        /// <remarks>
        /// Philippine receipts print MM/DD/YYYY; the driver's licence prints
        /// YYYY/MM/DD. Both are tried, and an impossible month-day combination is
        /// rejected rather than silently wrapped into the following month.
        /// </remarks>
        public static DateTime? FindFullDate(string? text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return null;

            var repaired = FuzzyText.RepairDigits(text);

            foreach (Match match in IsoDatePattern().Matches(repaired))
            {
                var date = Build(
                    int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture),
                    int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture),
                    int.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture));

                if (date is not null)
                    return date;
            }

            foreach (Match match in FullDatePattern().Matches(repaired))
            {
                var date = Build(
                    int.Parse(match.Groups[3].Value, CultureInfo.InvariantCulture),
                    int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture),
                    int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture));

                if (date is not null)
                    return date;
            }

            return null;
        }

        /// <summary>
        /// First month/year in the text, returned as the last day of that month.
        /// </summary>
        /// <remarks>
        /// Deliberately requires MM/YYYY and not MM/DD/YYYY. On the receipt the
        /// expiry is immediately followed by a renewal window — "01/2026 and due for
        /// renewal on 01/22/2026-01/31/2026" — and a rule that accepts either shape
        /// captures the window instead of the expiry.
        ///
        /// The last day of the month is used because registration is valid through
        /// the whole month, so the first would expire people early.
        /// </remarks>
        public static DateTime? FindMonthYear(string? text)
        {
            if (string.IsNullOrWhiteSpace(text))
                return null;

            var repaired = FuzzyText.RepairDigits(text);

            foreach (Match match in MonthYearPattern().Matches(repaired))
            {
                // Skip anything that is really part of a full date, so the day of a
                // "01/22/2026" is not mistaken for a month.
                if (match.Index > 0 && char.IsDigit(repaired[match.Index - 1]))
                    continue;

                var month = int.Parse(match.Groups[1].Value, CultureInfo.InvariantCulture);
                var year = int.Parse(match.Groups[2].Value, CultureInfo.InvariantCulture);

                if (month is < 1 or > 12 || year is < 2000 or > 2100)
                    continue;

                return new DateTime(year, month, DateTime.DaysInMonth(year, month), 0, 0, 0, DateTimeKind.Utc);
            }

            return null;
        }

        private static DateTime? Build(int year, int month, int day)
        {
            if (year is < 1950 or > 2100 || month is < 1 or > 12)
                return null;

            if (day < 1 || day > DateTime.DaysInMonth(year, month))
                return null;

            return new DateTime(year, month, day, 0, 0, 0, DateTimeKind.Utc);
        }
    }
}
