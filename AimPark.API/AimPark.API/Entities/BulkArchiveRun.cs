namespace AimPark.API.Entities
{
    /// <summary>
    /// One real bulk archive (never a preview), kept so the panel can say
    /// "last run Nov 19 · 14 archived · 7 left alone" and later spot who of
    /// those 7 has since become clear to archive.
    /// </summary>
    /// <remarks>
    /// Only the IDs of the people left alone are kept, not their names or
    /// reasons. Those go stale the moment someone pays, so they are worked out
    /// again from the live data every time the panel asks.
    /// </remarks>
    public class BulkArchiveRun
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public DateTime RanAt { get; set; } = DateTime.UtcNow;

        public Guid AdminUserId { get; set; }

        public int ArchivedCount { get; set; }

        /// <summary>The accounts the run had to skip (unpaid, parked, open violation).</summary>
        public List<Guid> LeftAloneUserIds { get; set; } = [];

        /// <summary>The reason the administrator gave, reused in the audit log for auto-archives.</summary>
        public string Reason { get; set; } = string.Empty;

        // ── Archive when clear ───────────────────────────────────────────────
        //
        // Off unless the administrator opted in. When on, each person left
        // alone has a BulkArchivePending row and the AutoArchiveService works
        // through them. Grace period and end date stay editable afterwards.

        public bool AutoArchive { get; set; }

        /// <summary>Days between the notice and the archive.</summary>
        public int GraceDays { get; set; } = 7;

        /// <summary>
        /// After this, nobody new is warned and anyone still waiting is
        /// dropped. Someone already warned still finishes their notice.
        /// </summary>
        public DateTime? AutoArchiveUntil { get; set; }

        /// <summary>When the administrator turned it off, or a newer run replaced it.</summary>
        public DateTime? AutoArchiveStoppedAt { get; set; }

        public List<BulkArchivePending> Pending { get; set; } = [];
    }
}
