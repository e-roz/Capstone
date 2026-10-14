using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// A licence or a vehicle registration that an approved user has renewed and
    /// uploaded again, waiting for an admin to accept it.
    /// </summary>
    /// <remarks>
    /// A table of its own rather than another <see cref="DocumentVerification"/>.
    /// That row is a machine verdict on a first submission, and the review queue
    /// and approval both read "the latest one"; a renewal there would be taken for
    /// the application it is not part of.
    ///
    /// Nothing on the user changes until approval. In particular this never
    /// touches <see cref="User.AccountStatus"/>: the user is Active throughout, and
    /// what a stale expiry costs them is decided at the gate, not by moving them
    /// back into the registration queue.
    /// </remarks>
    public class DocumentRenewal
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        /// <summary>The vehicle whose registration this renews. Null for a licence.</summary>
        public Guid? VehicleId { get; set; }
        public Vehicle? Vehicle { get; set; }

        /// <summary><see cref="DocumentType.License"/> or <see cref="DocumentType.OfficialReceipt"/>.</summary>
        public DocumentType Type { get; set; }

        public Guid DocumentId { get; set; }
        public Document Document { get; set; } = null!;

        /// <summary>What the phone's text recognition read off the new document.</summary>
        public DateTime? ExtractedExpiry { get; set; }

        /// <summary>What the user confirmed. This is the date applied on approval.</summary>
        public DateTime? NewExpiry { get; set; }

        public RenewalStatus Status { get; set; } = RenewalStatus.Draft;

        public Guid? ReviewedByUserId { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public string? RejectReason { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
