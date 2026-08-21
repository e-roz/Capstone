using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class PolicyRule
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        // Existing rules predate this field, so the migration defaults them to
        // Parking rather than Other: every rule written so far is a parking rule,
        // and defaulting to Other would mislabel all of them.
        public PolicyCategory Category { get; set; } = PolicyCategory.Parking;

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
