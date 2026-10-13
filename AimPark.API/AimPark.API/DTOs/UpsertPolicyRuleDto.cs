namespace AimPark.API.DTOs
{
    public class UpsertPolicyRuleDto
    {
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        /// <summary>Parking or Conduct.</summary>
        public string Category { get; set; } = "Parking";
        public decimal DefaultPenaltyAmount { get; set; }

        /// <summary>Temporary or Permanent. Every rule does something to the card.</summary>
        public string DefaultSuspensionType { get; set; } = "Temporary";
        public int? DefaultSuspensionHours { get; set; }

        /// <summary>
        /// Days the offender's card keeps working so they can appeal before the
        /// suspension starts. Zero means it starts at once — for rules where
        /// waiting is the unfair option.
        /// </summary>
        public int AppealWindowDays { get; set; } = 3;

        public bool IsActive { get; set; } = true;
    }
}
