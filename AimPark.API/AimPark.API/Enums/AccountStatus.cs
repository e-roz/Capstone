namespace AimPark.API.Enums
{
    public enum AccountStatus
    {
        PendingReview,
        Active,
        Rejected,
        Suspended,

        /// <summary>
        /// Lost parking access after three Accountable violations. Unlike
        /// Suspended, the user can still sign in — to see their violations,
        /// pay fines and appeal. Assigning a card reinstates them as Active.
        /// </summary>
        Revoked
    }
}
