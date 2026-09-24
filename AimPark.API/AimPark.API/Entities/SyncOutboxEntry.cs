namespace AimPark.API.Entities
{
    /// <summary>
    /// Something the site server has done that the cloud has not heard about
    /// yet. Only ever written on the site server; the cloud's copy of this
    /// table stays empty.
    /// </summary>
    /// <remarks>
    /// A row names the record, not its contents. The pusher reads the record as
    /// it stands when it sends, so an entry and its exit a minute later go up
    /// as one up-to-date row, and nothing is sent in a state it has since left.
    /// </remarks>
    public class SyncOutboxEntry
    {
        /// <summary>Order of arrival. Sending in this order keeps parents ahead of children.</summary>
        public long Id { get; set; }

        /// <summary>One of <see cref="Sync.SyncKinds"/>.</summary>
        public string Kind { get; set; } = string.Empty;

        /// <summary>The record's id, for every kind except a push.</summary>
        public Guid? EntityId { get; set; }

        /// <summary>JSON body, for a push only — it has no record of its own to read back.</summary>
        public string? Payload { get; set; }

        public DateTime EnqueuedAt { get; set; } = DateTime.UtcNow;
    }
}
