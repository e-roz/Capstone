namespace AimPark.API.Enums
{
    public enum RfidStatus
    {
        Unassigned,
        Active,
        Suspended,

        /// <summary>
        /// Taken away after three Accountable violations. The physical card
        /// went back into the pool; assigning this user a card again makes
        /// them Active.
        /// </summary>
        Revoked
    }
}
