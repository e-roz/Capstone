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
        AlprCamera
    }
}
