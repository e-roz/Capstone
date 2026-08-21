namespace AimPark.API.DTOs
{
    public class PolicyRuleResponse
    {
        public Guid RuleId { get; set; }
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public decimal DefaultPenaltyAmount { get; set; }
        public string DefaultSuspensionType { get; set; } = string.Empty;
        public int? DefaultSuspensionDays { get; set; }
        public bool IsActive { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }
}
