using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class PolicyRule
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        public decimal DefaultPenaltyAmount { get; set; }
        public SuspensionType DefaultSuspensionType { get; set; } = SuspensionType.None;
        // Only used when DefaultSuspensionType == Temporary
        public int? DefaultSuspensionDays { get; set; }

        // Rules are deactivated, never deleted, so past violations keep a valid reference.
        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
