namespace AimPark.API.Enums
{
    /// <summary>
    /// Whether a physical card, once revoked from a user, is safe to hand to
    /// someone else.
    /// </summary>
    public enum RfidCardState
    {
        /// <summary>Revoked for a reason that says nothing bad about the card
        /// itself (graduated, damaged, no longer needed) — free to reissue.</summary>
        Free,

        /// <summary>Revoked because the card left the holder's control without
        /// their say-so (lost, stolen). Reissuing it would hand a new student's
        /// gate access to whoever still has the physical card.</summary>
        Blocked
    }
}
