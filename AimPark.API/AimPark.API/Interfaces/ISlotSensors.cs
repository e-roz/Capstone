namespace AimPark.API.Interfaces
{
    /// <summary>
    /// Which bays have a sensor over them. Only the sensor says whether such a
    /// bay is occupied: an entry or exit tap never marks it, because the bay
    /// given at the gate is only a recommendation — the driver may park in
    /// another, and the sensor there is what reports it.
    /// </summary>
    public interface ISlotSensors
    {
        bool Watches(Guid slotId);
    }

    /// <summary>The cloud: no sensors, so taps keep marking bays as before.</summary>
    public sealed class NoSlotSensors : ISlotSensors
    {
        public bool Watches(Guid slotId) => false;
    }
}
