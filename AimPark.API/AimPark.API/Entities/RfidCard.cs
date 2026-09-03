using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// What the system remembers about a physical card after it stops being
    /// tied to a user — the only place a revoked UID is tracked once
    /// <see cref="User.RfidTagId"/> on the holder is cleared.
    /// </summary>
    /// <remarks>
    /// A row here exists only between "revoked" and "reissued to someone new" —
    /// assigning the tag to a fresh user deletes it, since a card in active use
    /// is not part of the pool an admin is choosing from. A blocked card is the
    /// exception: it stays here indefinitely, because the whole point is that
    /// nobody assigns it again.
    /// </remarks>
    public class RfidCard
    {
        /// <summary>Normalized UID — see <see cref="Helpers.RfidTag"/>.</summary>
        public string RfidTagId { get; set; } = string.Empty;

        public RfidCardState State { get; set; }
        public RfidRevokeReason Reason { get; set; }
        public string? Note { get; set; }

        /// <summary>
        /// The user it was last taken from, kept even if that account is later
        /// archived — an admin reading the free-cards list still needs to know
        /// whose card this used to be.
        /// </summary>
        public Guid LastUserId { get; set; }
        public string LastUserName { get; set; } = string.Empty;

        public DateTime UpdatedAt { get; set; }
    }
}
