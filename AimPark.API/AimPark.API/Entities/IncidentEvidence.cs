namespace AimPark.API.Entities
{
    public class IncidentEvidence
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to Incident
        public Guid IncidentId { get; set; }
        public Incident Incident { get; set; } = null!;

        public string StoragePath { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;

        public DateTime UploadedAt { get; set; } = DateTime.UtcNow;
    }
}
