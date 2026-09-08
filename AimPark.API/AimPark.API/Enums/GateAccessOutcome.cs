namespace AimPark.API.Enums
{
    /// <summary>
    /// Why an RFID tap that should have opened the barrier didn't.
    /// </summary>
    public enum GateAccessOutcome
    {
        /// <summary>RFID was valid; ALPR read a plate that matched nothing
        /// registered to the card holder.</summary>
        PlateMismatch,

        /// <summary>RFID was valid, but there was no usable ALPR reading to
        /// check it against — camera confirmed down, or nothing arrived in
        /// the matching window. Logged the same way either cause; a guard's
        /// fix is identical regardless of which one it was.</summary>
        AlprUnavailable
    }
}
