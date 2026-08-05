namespace AimPark.API.Enums
{
    public enum IncidentStatus
    {
        Submitted,
        UnderReview,
        Resolved,
        Dismissed,

        // Retracted by the reporter before anyone reviewed it. Persisted as a
        // string, so appending here is safe for existing rows.
        Withdrawn
    }
}
