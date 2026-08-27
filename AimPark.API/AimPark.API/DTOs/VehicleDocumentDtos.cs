namespace AimPark.API.DTOs
{
    /// <summary>
    /// The two documents that prove a vehicle, for someone adding one after
    /// registration.
    /// </summary>
    /// <remarks>
    /// Two rather than four, and the missing pair is the point: a second vehicle
    /// raises no new question about the person. Their enrolment and their licence
    /// were read when they registered and have not changed, so asking for them
    /// again would be paperwork for its own sake. What is unknown is which
    /// vehicle this is, which is exactly what the receipt and the plate answer.
    /// </remarks>
    public class VehicleDocumentUploadDto
    {
        /// <summary>LTO Official Receipt — the source of the plate number.</summary>
        public IFormFile? OfficialReceipt { get; set; }

        /// <summary>Photo of the physical plate on the vehicle.</summary>
        public IFormFile? PlatePhoto { get; set; }

        public string? OfficialReceiptOcr { get; set; }
        public string? PlatePhotoOcr { get; set; }
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
        /// Only sent when the printed date did not survive the photograph and the
        /// user typed it. The plate number is deliberately absent: it comes from
        /// the receipt the server already read, and a plate the user could retype
        /// here would put the typing hole straight back.
        /// </summary>
        public DateTime? RegistrationExpiry { get; set; }
    }
}
