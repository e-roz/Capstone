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
        public static bool IsExpired(DateTime? expiry, DateOnly today) =>
            expiry is DateTime date && DateOnly.FromDateTime(date) < today;
    }
}
