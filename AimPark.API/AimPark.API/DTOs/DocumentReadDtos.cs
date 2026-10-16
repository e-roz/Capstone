namespace AimPark.API.DTOs
{
    /// <summary>
    /// One document's OCR reading, sent as soon as it is photographed.
    /// </summary>
    /// <remarks>
    /// The text only, not the image. Nothing is stored and no attempt is counted:
    /// this lets the app tell the applicant what was read, and whether anything is
    /// missing or expired, before they move on to the next document. The full scan
    /// at the end still uploads the images and remains the authority.
    /// </remarks>
    public class ReadDocumentDto
    {
        /// <summary>"Raf", "License" or "OfficialReceipt".</summary>
        public string DocumentType { get; set; } = string.Empty;

        /// <summary>Serialised <see cref="OcrPayloadDto"/>.</summary>
        public string? Ocr { get; set; }

        /// <summary>
        /// The applicant has said the vehicle has no plate, so a receipt without one
        /// is not reported as missing a value.
        /// </summary>
        public bool NoPlate { get; set; }
    }

    /// <summary>
    /// What one document gave, and whether the applicant can move on.
    /// </summary>
    public class DocumentReadResponse
    {
        public string DocumentType { get; set; } = string.Empty;

        /// <summary>
        /// Why the photo should be taken again — unreadable, or a value missing —
        /// or null when it read well enough.
        /// </summary>
        public DocumentDiagnosisDto? Diagnosis { get; set; }

        /// <summary>The values this document should give and did not, in words.</summary>
        public List<string> MissingFields { get; set; } = [];

        /// <summary>
        /// Every value the rules could pull out. Only this document's fields mean
        /// anything; the others are always empty.
        /// </summary>
        public ExtractedValuesDto Extracted { get; set; } = new();

        /// <summary>The expiry date this document carries, for the licence and receipt.</summary>
        public ExpiryCheckDto? Expiry { get; set; }
    }

    /// <summary>
    /// The expiry date read off a licence or receipt, and whether it stops registration.
    /// </summary>
    public class ExpiryCheckDto
    {
        /// <summary>"LicenseExpiry" or "RegistrationExpiry".</summary>
        public string Field { get; set; } = string.Empty;

        public DateTime? Date { get; set; }

        /// <summary>The date has passed (Philippine calendar day).</summary>
        public bool IsExpired { get; set; }

        /// <summary>
        /// Worked out from the plate rather than read. A calculated date never
        /// blocks, because a misread plate would move it.
        /// </summary>
        public bool IsCalculated { get; set; }

        /// <summary>True when registration cannot continue with this document.</summary>
        public bool Blocks { get; set; }

        /// <summary>The applicant-facing sentence, or null when there is nothing to say.</summary>
        public string? Message { get; set; }
    }
}
