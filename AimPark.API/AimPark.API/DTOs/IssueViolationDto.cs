namespace AimPark.API.DTOs
{
    public class IssueViolationDto
    {
        public Guid UserId { get; set; }
        public Guid PolicyRuleId { get; set; }
        public string Description { get; set; } = string.Empty;
        public Guid? ParkingLogId { get; set; }

        // Optional overrides — if omitted, the referenced PolicyRule's defaults are used.
        public decimal? PenaltyAmountOverride { get; set; }
        public string? SuspensionTypeOverride { get; set; }
        public int? SuspensionDaysOverride { get; set; }
    }
}
