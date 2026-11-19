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
    }
}
