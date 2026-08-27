namespace AimPark.API.DTOs
{
    public class UpsertPolicyRuleDto
    {
        public string Title { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;

        /// <summary>Parking, Access, Conduct, Documentation or Other.</summary>
        public string Category { get; set; } = "Parking";
        public decimal DefaultPenaltyAmount { get; set; }
        public string DefaultSuspensionType { get; set; } = "None";
        public int? DefaultSuspensionDays { get; set; }

        /// <summary>
        /// Days the offender's card keeps working so they can appeal before the
        /// suspension starts. Zero means it starts at once — for rules where
        /// waiting is the unfair option.
        /// </summary>
        public int AppealWindowDays { get; set; } = 3;

        public bool IsActive { get; set; } = true;
    }
}
