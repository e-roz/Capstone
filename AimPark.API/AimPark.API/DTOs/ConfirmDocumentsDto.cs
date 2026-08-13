namespace AimPark.API.DTOs
{
    /// <summary>
    /// The values the user agreed to on the confirmation screen.
    /// </summary>
    /// <remarks>
    /// These are kept alongside what the rules read, never in place of it. Where the
    /// two differ the reviewer sees both, so an edit is visible rather than silently
    /// overwriting the evidence — which is what keeps "the machine read X, the person
    /// changed it to Y" answerable afterwards.
    /// </remarks>
    public class ConfirmDocumentsDto
    {
        /// <summary>The draft returned by the scan step.</summary>
        public Guid VerificationId { get; set; }

        public string? StudentNumber { get; set; }
        public string? StudentName { get; set; }
        public string? Section { get; set; }
        public string? Semester { get; set; }

        public string? LicenseName { get; set; }
        public DateTime? LicenseExpiry { get; set; }

        /// <summary>
        /// The plate the user settled on. Where the receipt and their typed value
        /// disagreed, this is them resolving it at the moment they can still check —
        /// rather than an admin guessing from photos three days later.
        /// </summary>
        public string? PlateNumber { get; set; }

        public DateTime? RegistrationExpiry { get; set; }
    }
}
