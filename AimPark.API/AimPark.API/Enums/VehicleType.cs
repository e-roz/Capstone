namespace AimPark.API.Enums
{
    /// <summary>
    /// The two vehicle classes the facility handles.
    ///
    /// Member names are the exact strings persisted and exchanged over the API.
    /// Slot allocation matches a user's vehicle against a slot's type, so both
    /// sides have to agree on spelling — they previously did not, with mobile
    /// registration writing "Car"/"Motorcycle" while slots used "Motor"/"4 Wheels".
    /// Display labels are a client concern.
    /// </summary>
    public enum VehicleType
    {
        Motorcycle,
        Car
    }
}
