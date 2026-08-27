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

        /// <summary>
        /// Days before the suspension starts, overriding the rule's own window.
        /// Zero suspends immediately.
        /// </summary>
        /// <remarks>
        /// For the case the rule cannot anticipate: the same rule broken in a
        /// way that has to stop today. Left null the rule decides, which is the
        /// normal path.
        /// </remarks>
        public int? AppealWindowDaysOverride { get; set; }
    }
}
