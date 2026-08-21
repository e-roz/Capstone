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
        public bool IsActive { get; set; } = true;
    }
}
