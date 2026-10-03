using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// A physical card kept at the guard post for lending to visitors — the
    /// counter token at a mall bag deposit, not anybody's own card.
    /// </summary>
    /// <remarks>
    /// Registered by an admin ahead of time, so the gate already knows the card
    /// is a visitor card before anyone is holding it. Tapping an idle one at the
    /// gate asks the guard who is in the car (see
    /// <c>PendingVisitorRegistrations</c>); each lending is its own
    /// <see cref="VisitorPass"/>, so the logs keep every visitor's name even
    /// though they all carried the same card.
    ///
    /// Owned by the cloud and copied to the site in the snapshot, the same way
    /// users are. The site only reads it.
    /// </remarks>
    public class VisitorCard
    {
        /// <summary>Normalized UID — see <see cref="Helpers.RfidTag"/>.</summary>
        public string RfidTagId { get; set; } = string.Empty;

        /// <summary>What is written on the card itself, e.g. "V1".</summary>
        public string Label { get; set; } = string.Empty;

        public VisitorCardState State { get; set; } = VisitorCardState.Active;

        /// <summary>Why it was blocked, when it was.</summary>
        public string? Note { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
