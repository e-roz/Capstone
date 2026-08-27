namespace AimPark.API.DTOs
{
    /// <summary>
    /// A reviewer asking for specific documents again, rather than refusing the
    /// whole application.
    /// </summary>
    public class RequestDocumentRetakeDto
    {
        public List<DocumentRetakeItemDto> Documents { get; set; } = [];

        /// <summary>
        /// Optional line covering the request as a whole, shown above the
        /// per-document reasons.
        /// </summary>
        public string? Note { get; set; }
    }

    /// <summary>
    /// One document to redo, and why.
    /// </summary>
    public class DocumentRetakeItemDto
    {
        /// <summary>A <c>DocumentType</c> member name: Raf, SchoolId, License,
        /// OfficialReceipt, PlatePhoto.</summary>
        public string Type { get; set; } = string.Empty;

        /// <summary>
        /// Shown to the applicant on the capture screen for that document.
        /// </summary>
        /// <remarks>
        /// Required. A document sent back without a reason is a retake the
        /// applicant will make identically, because nothing told them what was
        /// wrong with the first one.
        /// </remarks>
        public string Reason { get; set; } = string.Empty;
    }
}
