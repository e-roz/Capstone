namespace AimPark.API.Enums
{
    /// <summary>
    /// What kind of hardware a <see cref="Entities.GateDevice"/> key was
    /// issued to. Kept separate from the role claim so an RFID reader's key
    /// can't be used to post fake ALPR plate reads, or the other way around.
    /// </summary>
    public enum GateDeviceType
    {
        RfidReader,
        AlprCamera,

        /// <summary>
        /// The on-site server, not a piece of gate hardware. Its key reaches
        /// the site-sync endpoints and nothing else — entry and exit only take
        /// an <see cref="RfidReader"/>, and plate reads only an
        /// <see cref="AlprCamera"/>. Issue it with gate 0.
        /// </summary>
        SiteServer
    }
}
