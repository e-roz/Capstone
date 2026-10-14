namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a licence or registration has run out.
    /// </summary>
    /// <remarks>
    /// An expiry is a day, and the document is good through the end of it. So
    /// "expired" means the date is before today in Philippine time, not that the
    /// instant has passed: a licence that expires on the 14th still works on the
    /// 14th, and the server runs on UTC, which turns over eight hours before the
    /// campus does.
    ///
    /// No date is not expired. A document nobody could read a date from is a
    /// question for an admin, and refusing a driver at the barrier over a blank
    /// is worse than letting them in.
    /// </remarks>
    public static class DocumentExpiry
    {
        /// <summary>
        /// How many days ahead the admin side starts warning. Earlier than the
        /// 30 days the user is told, so an admin sees a problem coming well before
        /// the user's own countdown begins.
        /// </summary>
        public const int AdminWarningDays = 60;

        public const string ExpiredState = "Expired";
        public const string ExpiringState = "Expiring";

        /// <summary>Has a date, and it is comfortably in the future.</summary>
        public const string ValidState = "Valid";


        public static bool IsExpired(DateTime? expiry, DateOnly today) =>
            expiry is DateTime date && DateOnly.FromDateTime(date) < today;

        /// <summary>The most pressing thing about a user's documents, for the Users list.</summary>
        public sealed record Finding(string State, string What, DateTime Date);

        /// <summary>
        /// The most pressing of a user's licence and vehicle registrations, or null
        /// when none of them has a date.
        /// </summary>
        /// <remarks>
        /// Expired outranks expiring (within <see cref="AdminWarningDays"/>), which
        /// outranks valid, and among equals the earliest date wins: the one that has
        /// been wrong the longest, or will be wrong first. When everything is fine
        /// the result is still the nearest date, so the list can say when. Vehicles
        /// with no date are skipped. Pass only registrations that have one: an
        /// e-bike has none.
        /// </remarks>
        public static Finding? Worst(
            DateTime? licence,
            IEnumerable<(string Plate, DateTime? Registration)> registrations,
            DateOnly today)
        {
            var candidates = new List<(string What, DateTime Date)>();

            if (licence is DateTime l)
                candidates.Add(("Licence", l));

            foreach (var (plate, registration) in registrations)
            {
                if (registration is DateTime r)
                    candidates.Add(($"Registration {plate}", r));
            }

            return candidates
                .Select(c =>
                {
                    var days = DateOnly.FromDateTime(c.Date).DayNumber - today.DayNumber;
                    var state = days < 0
                        ? ExpiredState
                        : days <= AdminWarningDays ? ExpiringState : ValidState;
                    return (c.What, c.Date, State: state);
                })
                .OrderBy(c => c.State == ExpiredState ? 0 : c.State == ExpiringState ? 1 : 2)
                .ThenBy(c => c.Date)
                .Select(c => new Finding(c.State, c.What, c.Date))
                .FirstOrDefault();
        }
    }
}
