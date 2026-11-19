namespace AimPark.API.Enums
{
    /// <summary>
    /// Where one person left alone by a bulk archive stands on that run's
    /// "archive when clear" list.
    /// </summary>
    /// <remarks>Stored as a string, so appending is safe for existing rows.</remarks>
    public enum PendingArchiveState
    {
        /// <summary>Still not clear (unpaid, parked, open violation).</summary>
        Waiting,

        /// <summary>Clear and away from the lot; told the date their account goes.</summary>
        Warned,

        /// <summary>Archived, by the job or by an administrator some other way.</summary>
        Archived,

        /// <summary>Parked again after the run, so still using the lot. Never archived.</summary>
        Kept,

        /// <summary>Taken off the list by an administrator, or the run's auto-archive was turned off.</summary>
        Cancelled,

        /// <summary>The run's end date passed while they were still waiting.</summary>
        Expired
    }
}
