namespace AimPark.API.DTOs
{
    /// <summary>
    /// What happened and to whom. The penalty, suspension and appeal window
    /// all come from the policy rule — there are deliberately no override
    /// fields, so the same rule always means the same punishment.
    /// </summary>
    public class IssueViolationDto
    {
        public Guid UserId { get; set; }
        public Guid PolicyRuleId { get; set; }
        public string Description { get; set; } = string.Empty;
        public Guid? ParkingLogId { get; set; }
    }
}
