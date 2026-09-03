namespace AimPark.API.Enums
{
    /// <summary>
    /// Why an admin took a card off a user's account. Drives whether the card
    /// goes back into circulation or is blocked from ever being reissued — see
    /// <see cref="RfidCardState"/>.
    /// </summary>
    public enum RfidRevokeReason
    {
        Graduated,
        NoLongerNeeded,
        Damaged,
        Lost,
        Stolen,
        Other
    }
}
