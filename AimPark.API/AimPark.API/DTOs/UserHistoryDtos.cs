namespace AimPark.API.DTOs
{
    /// <summary>One page of a list on the user's detail tabs.</summary>
    public class UserHistoryPage<T>
    {
        public List<T> Items { get; set; } = [];
        public int Total { get; set; }
        public int Page { get; set; }
        public int PageSize { get; set; }
    }

    /// <summary>
    /// What the user detail page shows before any tab is opened: the numbers on
    /// the tab labels and the overview cards.
    /// </summary>
    public class UserHistorySummary
    {
        public int Sessions { get; set; }
        public int Violations { get; set; }
        public int IncidentsFiled { get; set; }

        /// <summary>Reports about a bay this person had a session in around the time.</summary>
        public int IncidentsPossible { get; set; }

        public int Taps { get; set; }

        /// <summary>Unpaid bills, as the gate counts them.</summary>
        public decimal Owed { get; set; }
        public decimal PaidThisYear { get; set; }

        /// <summary>The bay they are in now, or null when not parked or the bay is unknown.</summary>
        public string? InsideSlotCode { get; set; }
        public bool IsInside { get; set; }
        public DateTime? InsideSince { get; set; }
    }

    public class UserSessionItem
    {
        public Guid Id { get; set; }
        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }
        public int? Gate { get; set; }
        public string? SlotCode { get; set; }

        /// <summary>False means the bay is only the one the gate suggested.</summary>
        public bool SlotConfirmed { get; set; }

        public string? Plate { get; set; }
        public bool? PlateMatched { get; set; }
    }

    public class UserViolationItem
    {
        public Guid Id { get; set; }
        public string RuleTitle { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public decimal PenaltyAmount { get; set; }
        public DateTime CreatedAt { get; set; }

        /// <summary>Where it happened, when it was tied to a parking session.</summary>
        public string? SlotCode { get; set; }
        public DateTime? SessionEntry { get; set; }
    }

    public class UserIncidentItem
    {
        public Guid Id { get; set; }
        public string Category { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public string? Location { get; set; }
        public string? SlotCode { get; set; }

        /// <summary>For a possible one: when this person was in that bay, and whether they confirmed it.</summary>
        public DateTime? InvolvedEntry { get; set; }
        public DateTime? InvolvedExit { get; set; }
        public bool InvolvedConfirmed { get; set; }
    }

    public class UserIncidents
    {
        /// <summary>Reports this person filed.</summary>
        public List<UserIncidentItem> Filed { get; set; } = [];

        /// <summary>
        /// Reports about a bay this person was in around the time it was
        /// reported. A lead for the administrator, never a finding.
        /// </summary>
        public List<UserIncidentItem> PossiblyInvolved { get; set; } = [];
    }

    public class UserPaymentItem
    {
        public Guid Id { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime? PaidAt { get; set; }

        /// <summary>"Violation fine" or "Parking · N min".</summary>
        public string For { get; set; } = string.Empty;
        public decimal Amount { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}
