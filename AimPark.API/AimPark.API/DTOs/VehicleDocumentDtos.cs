namespace AimPark.API.DTOs
{
    /// <summary>
    /// The one document that proves a vehicle, for someone adding one after
    /// registration.
    /// </summary>
    /// <remarks>
    /// One rather than three, and the missing pair is the point: a second vehicle
    /// raises no new question about the person. Their enrolment and their licence
    /// were read when they registered and have not changed, so asking for them
    /// again would be paperwork for its own sake. What is unknown is which
    /// vehicle this is, which is exactly what the receipt answers.
    /// </remarks>
    public class VehicleDocumentUploadDto
    {
        /// <summary>LTO Official Receipt — the source of the plate number.</summary>
        public IFormFile? OfficialReceipt { get; set; }

        public string? OfficialReceiptOcr { get; set; }
    }

    /// <summary>
    /// The values the user agreed to, committing the vehicle.
    /// </summary>
    public class ConfirmVehicleDto
    {
        /// <summary>The draft the scan created.</summary>
        public Guid VerificationId { get; set; }

        /// <summary>Car or Motorcycle — the facility has no other bays.</summary>
        public string VehicleType { get; set; } = string.Empty;

        public string Color { get; set; } = string.Empty;

        /// <summary>
        /// The plate, pre-filled from the receipt's OCR reading and editable by the
        /// user. There is no plate photo to corroborate it any more, so a
        /// correction is trusted and, if it differs from the reading, flagged to
        /// the reviewer instead of silently accepted.
        /// </summary>
        public string? PlateNumber { get; set; }

        /// <summary>
        /// Only sent when the printed date did not survive the photograph and the
        /// user typed it.
        /// </summary>
        public DateTime? RegistrationExpiry { get; set; }
    }
}
