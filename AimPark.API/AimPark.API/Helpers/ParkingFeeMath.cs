namespace AimPark.API.Helpers
{
    /// <summary>
    /// How a parking session is priced, as plain arithmetic with no database.
    /// Every bill, the exit gate and the app's live fee use this, so they can
    /// never disagree about what a stay costs.
    /// </summary>
    public static class ParkingFeeMath
    {
        /// <summary>
        /// Minutes charged for a stay from <paramref name="entry"/> to
        /// <paramref name="at"/>. Rounded up, not to nearest: a started minute is
        /// a charged minute, which is how paid parking is billed everywhere.
        /// </summary>
        public static int ChargedMinutes(DateTime entry, DateTime at)
            => Math.Max(0, (int)Math.Ceiling((at - entry).TotalMinutes));

        /// <summary>Minutes × the hourly rate, before any minimum. Shown to the driver as the working.</summary>
        public static decimal Metered(decimal ratePerHour, int minutes)
            => Math.Round(ratePerHour / 60m * minutes, 2);

        /// <summary>
        /// What <paramref name="minutes"/> of parking costs: metered per minute,
        /// with <paramref name="minimumFee"/> as a floor (not a fee on top).
        /// </summary>
        /// <remarks>
        /// The floor exists because no card or e-wallet gateway in the country
        /// takes a payment under twenty pesos, so per-minute billing alone made
        /// bills that could not be paid online. A session that costs nothing
        /// stays nothing: no minimum for a driver who was never charged.
        /// </remarks>
        public static decimal Price(decimal ratePerHour, decimal minimumFee, int minutes)
        {
            var metered = Metered(ratePerHour, minutes);
            return metered > 0m && metered < minimumFee ? minimumFee : metered;
        }

        /// <summary>
        /// The next moment after <paramref name="at"/> when the price of the stay
        /// goes up, and what it goes up to. Null when it never will (no rate).
        /// </summary>
        /// <remarks>
        /// The charged minutes tick over the instant a new minute starts, so the
        /// price for <c>m</c> minutes applies from <c>entry + (m - 1) minutes</c>.
        /// Under the minimum, several minutes pass with no change, so this looks
        /// ahead minute by minute (at most a day) for the first real change.
        /// </remarks>
        public static (DateTime At, decimal Amount)? NextChange(
            decimal ratePerHour, decimal minimumFee, DateTime entry, DateTime at)
        {
            if (ratePerHour <= 0m) return null;

            var now = ChargedMinutes(entry, at);
            var current = Price(ratePerHour, minimumFee, now);

            for (var m = now + 1; m <= now + 24 * 60; m++)
            {
                var amount = Price(ratePerHour, minimumFee, m);
                if (amount > current)
                    return (entry.AddMinutes(m - 1), amount);
            }

            return null;
        }
    }
}
