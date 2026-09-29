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
        Account,

        // The outcome of an incident the user reported. Appended for the same
        // reason as the three above: the column stores the name, not the
        // ordinal, so adding to the end moves nothing.
        Incident,
        // Your own card at the gate: entered, left, or refused.
        Parking,
        // Raised on a clock rather than by an action: a bill due tomorrow or
        // overdue, a suspension starting, access coming back.
        Reminder
    }
}
