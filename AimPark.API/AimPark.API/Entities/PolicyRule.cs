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

        /// <summary>
        /// Days the user's card keeps working after this rule is broken, so
        /// they can appeal before the suspension starts. Zero means the
        /// suspension bites immediately.
        /// </summary>
        /// <remarks>
        /// Three days is the right default — a penalty served before anyone has
        /// read the objection makes the appeal pointless. But not every rule
        /// deserves it: blocking a fire lane or a repeated forced entry has to
        /// stop today, and waiting three days to act on one is its own kind of
        /// unfair. So the window belongs to the rule, where an admin writing
        /// the rule can weigh exactly that, rather than being one constant for
        /// the whole system.
        ///
        /// Only meaningful when <see cref="DefaultSuspensionType"/> is not
        /// None. Rules written before this field default to three days.
        /// </remarks>
        public int AppealWindowDays { get; set; } = 3;

        // Rules are deactivated, never deleted, so past violations keep a valid reference.
        public bool IsActive { get; set; } = true;

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
