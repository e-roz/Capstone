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
        /// The plate, pre-filled from the receipt's OCR reading and editable by the
        /// user, same as every other field here. There is no plate photo left to
        /// corroborate the reading, so a correction is trusted; if it differs from
        /// what the receipt produced, that is recorded as an edit and reaches the
        /// reviewer as one, same as a corrected name or student number.
        /// </summary>
        public string? PlateNumber { get; set; }

        public DateTime? RegistrationExpiry { get; set; }

        /// <summary>
        /// Car or Motorcycle, chosen by the user. Not readable from any document —
        /// text recognition returns words, and the body type is not printed on the
        /// receipt — and slot allocation cannot run without it.
        /// </summary>
        public string? VehicleType { get; set; }

        /// <summary>Chosen from a swatch, for the same reason as the type.</summary>
        public string? Color { get; set; }
    }
}
