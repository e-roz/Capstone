namespace AimPark.API.Helpers
{
    /// <summary>
    /// The campus's calendar, for the cloud, which runs in UTC.
    /// </summary>
    /// <remarks>
    /// Times are stored in UTC. A "day" on a report has to be the Philippine
    /// day (midnight to midnight, UTC+8), or "today" starts at 8 in the morning
    /// and an entry at 6 AM lands on the day before. The Philippines has no
    /// daylight saving, so a fixed offset is exact and needs no tz database,
    /// which the Windows and Linux hosts name differently.
    /// </remarks>
    public static class PhilippineTime
    {
        public static readonly TimeSpan Offset = TimeSpan.FromHours(8);

        /// <summary>The Philippine calendar date right now.</summary>
        public static DateOnly Today() => LocalDate(DateTime.UtcNow);

        /// <summary>The Philippine calendar date of a UTC moment.</summary>
        public static DateOnly LocalDate(DateTime utc) => DateOnly.FromDateTime(utc.Add(Offset));

        /// <summary>The Philippine hour of the day (0-23) of a UTC moment.</summary>
        public static int LocalHour(DateTime utc) => utc.Add(Offset).Hour;

        /// <summary>The UTC moment a Philippine day begins.</summary>
        public static DateTime StartOfDayUtc(DateOnly day) =>
            DateTime.SpecifyKind(day.ToDateTime(TimeOnly.MinValue) - Offset, DateTimeKind.Utc);
    }
}
