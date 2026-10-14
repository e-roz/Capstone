namespace AimPark.API.DTOs
{
    /// <summary>
    /// What an admin records at the in-person inspection of an e-bike, sent as a
    /// multipart form because the photos travel with it.
    /// </summary>
    /// <remarks>
    /// Photos, brand, colour and marks are the e-bike's identity: it has no LTO
    /// plate and no receipt, so these are all that says which e-bike this is.
    /// The three confirmations are the checklist on the review screen, sent as
    /// fields so the rule that they must all be ticked lives on the server and not
    /// only in a disabled button.
    /// </remarks>
    public class EBikeInspectionDto
    {
        public string? Brand { get; set; }
        public string? Color { get; set; }
        public string? DistinguishingMarks { get; set; }

        /// <summary>"Motorcycle" (fits a motorcycle bay) or "Car" (needs a car bay).</summary>
        public string? SizeClass { get; set; }

        public bool LicenseMatchesPerson { get; set; }
        public bool SeenInPerson { get; set; }
        public bool NoLtoPlate { get; set; }

        /// <summary>Front, side and back, at least. Sent again on a retry, which replaces the earlier set.</summary>
        public List<IFormFile> Photos { get; set; } = [];

        /// <summary>Same meaning as on <see cref="ApproveRegistrationDto"/>.</summary>
        public string? OverrideNote { get; set; }
    }
}
