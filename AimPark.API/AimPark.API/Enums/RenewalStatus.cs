namespace AimPark.API.Enums
{
    /// <summary>Where a renewed licence or registration is in its review.</summary>
    public enum RenewalStatus
    {
        /// <summary>Photographed and read, but the user has not confirmed the date yet.</summary>
        Draft,

        /// <summary>Waiting for an admin. The old expiry still stands until it is approved.</summary>
        Pending,

        Approved,
        Rejected
    }
}
