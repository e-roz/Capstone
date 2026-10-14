namespace AimPark.API.Helpers
{
    /// <summary>How a report groups its points: one per day, week or month.</summary>
    public enum ReportGranularity
    {
        Day,
        Week,
        Month
    }

    /// <summary>
    /// What a report was asked about, as the request spelled it: a number of
    /// days back, a from/to range, or everything.
    /// </summary>
    /// <param name="Days">Used when no range is given. Clamped to 1-90, as it always was.</param>
    /// <param name="From">First Philippine day of a range.</param>
    /// <param name="To">Last Philippine day of a range, inclusive.</param>
    /// <param name="AllTime">From the first record to today.</param>
    public record ReportQuery(int Days, DateOnly? From = null, DateOnly? To = null, bool AllTime = false)
    {
        public bool HasRange => AllTime || From is not null || To is not null;
    }

    /// <summary>
    /// A resolved stretch of Philippine days, with the UTC moments it covers
    /// and how finely to cut it.
    /// </summary>
    /// <remarks>
    /// Cut by length, so a chart never has to draw hundreds of bars: up to two
    /// months is one point per day, up to a year and a bit one per week, beyond
    /// that one per month. A week starts on Monday.
    /// </remarks>
    public sealed record ReportPeriod(DateOnly First, DateOnly Last)
    {
        /// <summary>The longest a range may be. Anything older is not a parking lot's history.</summary>
        public const int MaxDays = 3660;

        private const int DayLimit = 62;
        private const int WeekLimit = 400;

        public int Days => Last.DayNumber - First.DayNumber + 1;

        /// <summary>The moment the first day begins, in UTC.</summary>
        public DateTime StartUtc => PhilippineTime.StartOfDayUtc(First);

        /// <summary>The moment after the last day ends, in UTC. Compare with <c>&lt;</c>.</summary>
        public DateTime EndUtc => PhilippineTime.StartOfDayUtc(Last.AddDays(1));

        public ReportGranularity Granularity =>
            Days <= DayLimit ? ReportGranularity.Day
            : Days <= WeekLimit ? ReportGranularity.Week
            : ReportGranularity.Month;

        /// <summary>The first day of the point a day belongs to.</summary>
        public DateOnly BucketOf(DateOnly day) => Granularity switch
        {
            ReportGranularity.Day => day,
            ReportGranularity.Week => day.AddDays(-(((int)day.DayOfWeek + 6) % 7)),
            _ => new DateOnly(day.Year, day.Month, 1)
        };

        /// <summary>Every point the period holds, oldest first, including empty ones.</summary>
        public List<DateOnly> Buckets()
        {
            var buckets = new List<DateOnly>();
            for (var day = BucketOf(First); day <= Last; day = Next(day))
                buckets.Add(day);
            return buckets;
        }

        private DateOnly Next(DateOnly bucket) => Granularity switch
        {
            ReportGranularity.Day => bucket.AddDays(1),
            ReportGranularity.Week => bucket.AddDays(7),
            _ => bucket.AddMonths(1)
        };

        public bool Contains(DateTime utc) => utc >= StartUtc && utc < EndUtc;

        /// <param name="earliest">The first day anything was recorded; what "all time" starts from.</param>
        public static ReportPeriod From(ReportQuery query, DateOnly today, DateOnly? earliest = null)
        {
            if (query.AllTime)
                return Clamp(earliest ?? today, today, today);

            if (query.From is not null || query.To is not null)
            {
                var from = query.From ?? query.To!.Value;
                var to = query.To ?? today;
                if (from > to) (from, to) = (to, from);
                return Clamp(from, to, today);
            }

            var days = Math.Clamp(query.Days, 1, 90);
            return new ReportPeriod(today.AddDays(-(days - 1)), today);
        }

        // Nothing has happened tomorrow, and a ten-year cap keeps a typo from
        // asking the database for a thousand years of empty weeks.
        private static ReportPeriod Clamp(DateOnly from, DateOnly to, DateOnly today)
        {
            if (to > today) to = today;
            if (from > to) from = to;
            var earliestAllowed = to.AddDays(-(MaxDays - 1));
            if (from < earliestAllowed) from = earliestAllowed;
            return new ReportPeriod(from, to);
        }
    }
}
