using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// One person a bulk archive had to leave alone, waiting to be archived
    /// once they are clear. Only exists for runs with auto-archive turned on.
    /// </summary>
    /// <remarks>
    /// The path is Waiting → Warned → Archived. A Warned person who stops
    /// being clear (a new bill) goes back to Waiting. Parking again at any
    /// point after the run ends it as Kept: they are still using the lot.
    /// </remarks>
    public class BulkArchivePending
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid RunId { get; set; }
        public BulkArchiveRun Run { get; set; } = null!;

        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        public PendingArchiveState State { get; set; } = PendingArchiveState.Waiting;

        /// <summary>
        /// One line for the panel: today's skip reason while waiting, or what
        /// ended it ("Parked again Nov 21", "Cancelled by admin").
        /// </summary>
        public string? Note { get; set; }

        /// <summary>When they were told. Null until then.</summary>
        public DateTime? WarnedAt { get; set; }

        /// <summary>WarnedAt plus the run's grace period. Moves if the grace period is edited.</summary>
        public DateTime? ArchiveAt { get; set; }

        /// <summary>When it reached Archived, Kept, Cancelled or Expired.</summary>
        public DateTime? ResolvedAt { get; set; }

        public bool IsOpen => State is PendingArchiveState.Waiting or PendingArchiveState.Warned;
    }
}
