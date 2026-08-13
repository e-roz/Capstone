namespace AimPark.API.Helpers
{
    /// <summary>
    /// The LTO's staggered renewal scheme, used to work out when a registration runs
    /// out without reading the receipt's small print.
    /// </summary>
    /// <remarks>
    /// Renewal months are assigned nationally by plate number: the last digit sets
    /// the month, 1 for January through 9 for September, and 0 for October.
    ///
    /// This matters because the expiry is printed in the paragraph that survives
    /// photography worst. In diagnostic testing the printed expiry did not come back
    /// at all, while the plate read at 0.90 confidence and the receipt date read
    /// cleanly — both in large print. Deriving from those two beats reading a
    /// paragraph that is not there.
    ///
    /// Verified against one document: plate ending 1 predicted January, matching the
    /// printed 01/2026. That is good evidence and a single sample. Treat a derived
    /// expiry as weaker than a read one, and confirm against a second receipt from a
    /// different vehicle before relying on it.
    /// </remarks>
    public static class RegistrationRenewal
    {
        /// <summary>
        /// Renewal month implied by a plate's last digit, or null if it has none.
        /// </summary>
        public static int? RenewalMonthFromPlate(string? plate)
        {
            if (string.IsNullOrWhiteSpace(plate))
                return null;

            var lastDigit = plate.LastOrDefault(char.IsDigit);
            if (lastDigit == default)
                return null;

            var digit = lastDigit - '0';

            // Only ten months are used by the scheme; November and December are not
            // renewal months.
            return digit == 0 ? 10 : digit;
        }

        /// <summary>
        /// The next time this plate's renewal month falls due after the receipt was
        /// issued.
        /// </summary>
        /// <remarks>
        /// Registration runs annually, so a receipt paid in July 2025 against a
        /// January renewal is good until January 2026 — which is what the sample
        /// document states. Returns the last day of that month, since the
        /// registration is valid through it.
        /// </remarks>
        public static DateTime? DeriveExpiry(string? plate, DateTime? receiptDate)
        {
            if (receiptDate is null)
                return null;

            var month = RenewalMonthFromPlate(plate);
            if (month is null)
                return null;

            var issued = receiptDate.Value;
            var year = issued.Year;

            // Strictly after the month of issue: paying in your renewal month buys
            // the following year, not the one just ending.
            if (month.Value <= issued.Month)
                year++;

            return new DateTime(year, month.Value, DateTime.DaysInMonth(year, month.Value), 0, 0, 0, DateTimeKind.Utc);
        }
    }
}
