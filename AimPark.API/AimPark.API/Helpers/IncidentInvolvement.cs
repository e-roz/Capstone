namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a parking session puts someone near a reported incident.
    /// </summary>
    /// <remarks>
    /// A session counts when it overlapped the stretch of time before the
    /// report: damage is usually found some time after it happened. The window
    /// covers the whole day of the report (Manila time), and never less than
    /// <see cref="MinimumLookBack"/>, so a report just after midnight still
    /// reaches the evening before. A session with no exit time is still going.
    /// The admin panel's "who was in this bay" section uses the same window, so
    /// the two never disagree.
    /// </remarks>
    public static class IncidentInvolvement
    {
        public static readonly TimeSpan MinimumLookBack = TimeSpan.FromHours(6);

        /// <summary>Manila has no daylight saving, so a fixed offset is exact.</summary>
        private static readonly TimeSpan Manila = TimeSpan.FromHours(8);

        /// <summary>When the window opens for a report made at <paramref name="reportedAt"/> (UTC).</summary>
        public static DateTime WindowStart(DateTime reportedAt)
        {
            var manilaMidnight = (reportedAt + Manila).Date - Manila;
            var minimum = reportedAt - MinimumLookBack;
            return manilaMidnight < minimum ? manilaMidnight : minimum;
        }

        public static bool Overlaps(DateTime entry, DateTime? exit, DateTime reportedAt)
        {
            if (entry > reportedAt) return false;
            if (exit is DateTime left && left < WindowStart(reportedAt)) return false;
            return true;
        }
    }
}
