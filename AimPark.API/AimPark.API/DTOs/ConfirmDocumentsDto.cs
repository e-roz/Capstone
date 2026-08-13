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
        /// The plate, as read off the receipt. Echoed back rather than typed — the
        /// app shows it read-only, because a plate is what the gate camera matches
        /// on and a hand-corrected one proves nothing about the vehicle.
        /// </summary>
        /// <remarks>
        /// Still compared against the stored reading on arrival. A value that does
        /// not match what the scan produced did not come from this flow, so it is
        /// recorded as an edit and reaches the reviewer as one.
        /// </remarks>
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

        /// <summary>
        /// Optional. Nothing in the system reads either — the gate matches on the
        /// plate and allocation on the type — so they are offered rather than
        /// demanded, and left blank by anyone who does not care to fill them in.
        /// </summary>
        public string? Brand { get; set; }

        public string? Model { get; set; }
    }
}
