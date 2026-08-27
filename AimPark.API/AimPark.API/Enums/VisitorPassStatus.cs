namespace AimPark.API.Enums
{
    /// <summary>
    /// Where a lent-out visitor card is in its short life.
    /// </summary>
    public enum VisitorPassStatus
    {
        /// <summary>Card is with the visitor and opens the barrier.</summary>
        Active,

        /// <summary>Card was handed back. It can be lent to somebody else.</summary>
        Returned,

        /// <summary>
        /// The pass ran past its expiry with the card still out. The card stops
        /// working, but the pass stays open so the guard can see the card is
        /// missing rather than the row quietly disappearing.
        /// </summary>
        Expired
    }
}
