namespace AimPark.API.Enums
{
    public enum ParkingSlotStatus
    {
        Available,
        Occupied,
        OutOfService,

        /// <summary>
        /// The bay's sensor can't see: it hears no echo, or its board is
        /// offline. Not offered and not counted free until it reads again.
        /// </summary>
        NoSignal
    }
}
