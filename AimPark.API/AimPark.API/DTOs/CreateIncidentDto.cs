namespace AimPark.API.DTOs
{
    public class CreateIncidentDto
    {
        public string Category { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string? Location { get; set; }

        /// <summary>The bay the report is about, if the reporter picked one.</summary>
        public Guid? SlotId { get; set; }
        public List<IFormFile>? Evidence { get; set; }
    }
}
