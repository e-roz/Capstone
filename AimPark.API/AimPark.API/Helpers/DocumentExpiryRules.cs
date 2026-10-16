using AimPark.API.DTOs;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// What registration does with a licence or registration that has run out.
    /// </summary>
    /// <remarks>
    /// An expired document stops registration on the spot, rather than reaching a
    /// reviewer only to be rejected. The applicant is shown the date that was read,
    /// so a misread can be corrected, and the corrected date is checked again.
    ///
    /// Two things keep this honest. A registration expiry the rules calculated from
    /// the plate, rather than read, never blocks anyone: a misread plate digit would
    /// move it by months. And an edit that turns an expired reading into a valid
    /// date is allowed but written down for the reviewer, because the system cannot
    /// tell a corrected misread from a lie.
    /// </remarks>
    public static class DocumentExpiryRules
    {
        /// <summary>Opening words of the note for an expired reading edited into a valid date.</summary>
        public const string ExpiredReadingEditedMarker = "Expiry changed from an expired date";

        /// <summary>Opening words of the note for a typed date the photo does not show.</summary>
        public const string TypedDateNotOnPhotoMarker = "Typed date not on the photo";

        public static string LicenceExpiredMessage(DateTime expiry) =>
            $"We read your driver's licence expiry as {expiry:MMMM d, yyyy}. This licence is expired. "
            + "Please use a valid licence. If we misread the date, correct it.";

        public static string RegistrationExpiredMessage(DateTime expiry) =>
            $"We read this vehicle's registration as valid until {expiry:MMMM d, yyyy}. This registration is "
            + "expired. Please use a renewed official receipt. If we misread the date, correct it.";

        /// <summary>
        /// Why the licence stops registration, or null when it does not.
        /// </summary>
        public static string? LicenceRefusal(DateTime? expiry, DateOnly today) =>
            expiry is DateTime date && DocumentExpiry.IsExpired(date, today)
                ? LicenceExpiredMessage(date)
                : null;

        /// <summary>
        /// Why the vehicle registration stops registration, or null when it does
        /// not. A <paramref name="calculated"/> date never blocks; the reviewer's
        /// expiry check still shows it.
        /// </summary>
        public static string? RegistrationRefusal(DateTime? expiry, bool calculated, DateOnly today) =>
            !calculated && expiry is DateTime date && DocumentExpiry.IsExpired(date, today)
                ? RegistrationExpiredMessage(date)
                : null;

        /// <summary>
        /// A note for the reviewer when the applicant changed an expired reading into
        /// a date that has not passed.
        /// </summary>
        public static string? ExpiredReadingEditedNote(
            string document, DateTime? read, DateTime? submitted, DateOnly today)
        {
            if (read is not DateTime readDate || submitted is not DateTime submittedDate)
                return null;

            if (!DocumentExpiry.IsExpired(readDate, today) || DocumentExpiry.IsExpired(submittedDate, today))
                return null;

            return $"{ExpiredReadingEditedMarker} — the {document} reads {readDate:MMMM d, yyyy}, which has "
                   + $"passed, but the applicant submitted {submittedDate:MMMM d, yyyy}. Check the photo.";
        }

        /// <summary>
        /// A note for the reviewer when nothing was read and the applicant typed a
        /// date that appears nowhere in the photo's text.
        /// </summary>
        /// <remarks>
        /// A soft signal only. The OCR may have missed the date and the typed one may
        /// be right, which is exactly why this warns rather than blocks. When the OCR
        /// returned no text at all there is nothing to compare, and nothing is said.
        /// </remarks>
        public static string? TypedDateNotOnPhotoNote(
            string document, DateTime? read, DateTime? submitted, IReadOnlyCollection<OcrLineDto> lines)
        {
            if (read is not null || submitted is not DateTime typed || lines.Count == 0)
                return null;

            if (DatesIn(lines).Contains(typed.Date))
                return null;

            return $"{TypedDateNotOnPhotoMarker} — the applicant typed {typed:MMMM d, yyyy} for the {document}, "
                   + "and no such date was found in the photo's text. Check the photo.";
        }

        /// <summary>
        /// Every date the photo's text carries, as full dates and as month/year
        /// (taken as the month's last day, the way registration expiry is stored).
        /// </summary>
        private static HashSet<DateTime> DatesIn(IEnumerable<OcrLineDto> lines)
        {
            var found = new HashSet<DateTime>();

            foreach (var line in lines)
            {
                foreach (var token in line.Text.Split(' ', StringSplitOptions.RemoveEmptyEntries))
                {
                    if (DateExtraction.FindFullDate(token) is DateTime full)
                        found.Add(full.Date);

                    if (DateExtraction.FindMonthYear(token) is DateTime monthYear)
                        found.Add(monthYear.Date);
                }
            }

            return found;
        }
    }
}
