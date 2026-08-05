namespace AimPark.API.Enums
{
    public enum NotificationType
    {
        Announcement,
        PolicyUpdate,
        ParkingAvailability,
        System,

        // Addressed to one person rather than broadcast. Persisted as a string,
        // so appending here is safe for existing rows.
        Violation,
        Payment,
        Account
    }
}
