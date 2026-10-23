namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a parking session puts someone near a reported incident.
    /// </summary>
    /// <remarks>
    /// A session counts when it overlapped the stretch of time just before the
    /// report: damage is usually found some time after it happened, so the
    /// window reaches back <see cref="LookBack"/> and ends at the report. A
    /// session with no exit time is still going. The admin panel's "who was in
    /// this bay" section uses the same six hours, so the two never disagree.
    /// </remarks>
    public static class IncidentInvolvement
    {
        public static readonly TimeSpan LookBack = TimeSpan.FromHours(6);

        public static bool Overlaps(DateTime entry, DateTime? exit, DateTime reportedAt)
        {
            if (entry > reportedAt) return false;
            if (exit is DateTime left && left < reportedAt - LookBack) return false;
            return true;
        }
    }
}
