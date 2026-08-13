namespace AimPark.API.Enums
{
    /// <summary>
    /// Why a field is worth the user's attention on the confirmation screen.
    /// </summary>
    public enum FieldFlag
    {
        /// <summary>
        /// The rules found nothing. The user has to type it, and the screen should
        /// say so rather than presenting an unexplained blank.
        /// </summary>
        NotFound,

        /// <summary>
        /// Worked out rather than read — the registration expiry calculated from the
        /// plate's renewal digit when the printed date did not survive photography.
        /// Weaker evidence than a reading, so it is worth a glance, but the user does
        /// not need to do anything if it looks right.
        /// </summary>
        Derived
    }
}
