namespace AimPark.API.Enums
{
    public enum AppealStatus
    {
        Pending,
        Approved,
        Denied,

        /// <summary>
        /// The violation was dismissed while this appeal was waiting, so there
        /// is nothing left to decide.
        /// </summary>
        Dismissed
    }
}
