namespace AimPark.API.DTOs
{
    /// <summary>
    /// The four files collected at the document step, each with what the phone read
    /// from it.
    /// </summary>
    /// <remarks>
    /// Property names are the multipart field names the app must send. They once
    /// drifted from what each file actually was — the back of a government ID
    /// arrived as "OR" — so each is named for the document it holds.
    ///
    /// The OCR payloads travel with the images rather than in a follow-up call, so
    /// the stored image and the reading of it can never disagree.
    ///
    /// Every file is nullable, and which ones are actually required is decided per
    /// request rather than here. A first submission needs all four; an applicant
    /// answering a reviewer's request for one unreadable receipt sends that receipt
    /// alone, and requiring the other three would be the system asking for
    /// photographs it already holds and had already accepted.
    /// </remarks>
    public class DocumentUploadDTO
    {
        /// <summary>
        /// Proof of school affiliation: a RAF for students, a school ID for faculty
        /// and staff. One slot rather than two, because exactly one is ever sent and
        /// the user's affiliation already says which.
        /// </summary>
        public IFormFile? IdentityDocument { get; set; }

        public IFormFile? License { get; set; }

        /// <summary>LTO Official Receipt — the source of the plate number.</summary>
        public IFormFile? OfficialReceipt { get; set; }

        /// <summary>Photo of the physical plate on the vehicle.</summary>
        public IFormFile? PlatePhoto { get; set; }

        // Serialised OcrPayloadDto, one per image. Optional: a phone that cannot run
        // text recognition still submits, and the whole thing falls to manual review
        // rather than blocking the applicant.
        public string? IdentityDocumentOcr { get; set; }
        public string? LicenseOcr { get; set; }
        public string? OfficialReceiptOcr { get; set; }
        public string? PlatePhotoOcr { get; set; }
    }
}
