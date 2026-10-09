namespace AimPark.API.DTOs
{
    /// <summary>A live wrong-bay warning, for the parking map.</summary>
    public class WrongBayFlagResponse
    {
        public Guid FlagId { get; set; }
        public Guid SlotId { get; set; }
        public string SlotCode { get; set; } = string.Empty;
        public int Gate { get; set; }

        /// <summary>"Car" or "Motorcycle": what the bay is for.</summary>
        public string? BayType { get; set; }

        /// <summary>"Open", "Confirmed" or "FalseAlarm".</summary>
        public string Status { get; set; } = string.Empty;

        public DateTime DetectedAt { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public string? ReviewedByName { get; set; }
    }

    public class ReviewWrongBayFlagDto
    {
        /// <summary>"Confirmed" or "FalseAlarm".</summary>
        public string Outcome { get; set; } = string.Empty;
    }
}
