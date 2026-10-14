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

        /// <summary>The guard's follow-up report, written when they confirmed.</summary>
        public string? ReviewNote { get; set; }
    }

    public class ReviewWrongBayFlagDto
    {
        /// <summary>"Confirmed" or "FalseAlarm".</summary>
        public string Outcome { get; set; } = string.Empty;

        /// <summary>Optional follow-up report for the administrator. Kept on a confirm only.</summary>
        public string? Note { get; set; }
    }
}
