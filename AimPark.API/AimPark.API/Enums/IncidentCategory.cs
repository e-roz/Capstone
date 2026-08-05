namespace AimPark.API.Enums
{
    public enum IncidentCategory
    {
        // Offered in the mobile reporting screen. These are the names the client
        // sends — display labels ("Blocked Slot") are a client-side concern.
        Vandalism,
        Theft,
        Accident,
        BlockedSlot,
        SuspiciousActivity,
        Other,

        // Retained so incidents filed before the client and server category lists
        // were aligned still deserialise. Not offered in the picker. Category is
        // persisted as a string, so member order here is not significant.
        Safety,
        VehicleDamage
    }
}
