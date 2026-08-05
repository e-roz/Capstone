namespace AimPark.API.DTOs
{
    /// <summary>
    /// Corrections to a report the user already filed. Evidence is not editable
    /// here — attachments are append-only, so removing a photo after submission
    /// cannot be used to weaken a report someone else relies on.
    /// </summary>
    public class UpdateIncidentDto
    {
        public string Category { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string? Location { get; set; }
    }
}
