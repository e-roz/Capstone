namespace AimPark.API.DTOs
{
    /// <summary>
    /// Who has used one bay, for the admin panel's slot history and for the
    /// incident lookup ("who claimed this bay when it was reported?").
    /// </summary>
    public class SlotHistoryResponse
    {
        public Guid SlotId { get; set; }
        public string SlotCode { get; set; } = string.Empty;
        public int Gate { get; set; }

        /// <summary>"Car" or "Motorcycle": what the bay is for. Null takes any vehicle.</summary>
        public string? BayType { get; set; }

        /// <summary>The session in the bay right now, if there is one.</summary>
        public SlotSessionItem? Current { get; set; }

        /// <summary>Newest first. Only the sessions that overlap the requested window.</summary>
        public List<SlotSessionItem> Sessions { get; set; } = [];

        public List<SlotViolationItem> Violations { get; set; } = [];
        public List<SlotWrongBayItem> WrongBayFlags { get; set; } = [];

        /// <summary>True when <see cref="Sessions"/> was cut at the page limit.</summary>
        public bool Truncated { get; set; }
    }

    public class SlotSessionItem
    {
        public Guid LogId { get; set; }

        /// <summary>Null when the session is a visitor's.</summary>
        public Guid? UserId { get; set; }

        /// <summary>The account holder, or the visitor's name.</summary>
        public string UserName { get; set; } = string.Empty;

        public string? PlateNumber { get; set; }
        public bool IsVisitor { get; set; }
        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        /// <summary>
        /// When the driver confirmed this bay in the app. Null = the bay is only
        /// the one the gate suggested, which is not proof of where they parked.
        /// </summary>
        public DateTime? ConfirmedAt { get; set; }
    }

    public class SlotViolationItem
    {
        public Guid ViolationId { get; set; }
        public Guid UserId { get; set; }
        public string UserName { get; set; } = string.Empty;
        public string RuleTitle { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class SlotWrongBayItem
    {
        public Guid FlagId { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime DetectedAt { get; set; }
        public DateTime? BayClearedAt { get; set; }
    }
}
