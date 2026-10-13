namespace AimPark.API.Enums
{
    public enum AccountStatus
    {
        PendingReview,
        Active,
        Rejected,

        /// <summary>
        /// Lost the account after three Accountable violations. Final: the
        /// user cannot sign in, owes nothing, and is never given a card again.
        /// Their student, licence and plate numbers stay on file, so the same
        /// documents cannot be used to register again.
        /// </summary>
        Revoked
    }
}
