namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the server read, returned for the user to check before it is committed.
    /// </summary>
    public class ScanResultResponse
    {
        /// <summary>The draft this scan created. Sent back when confirming.</summary>
        public Guid VerificationId { get; set; }

        /// <summary>
        /// Scans left before the flow stops asking for retakes. Some documents
        /// genuinely cannot be read — a faded photocopy folded down the middle — and
        /// no number of retakes will fix that. The system tries hard, then gets out
        /// of the way.
        /// </summary>
        public int TriesLeft { get; set; }

        /// <summary>
        /// False while a retake would still help and attempts remain. True once the
        /// documents read well enough, or once the attempts are spent and the user
        /// should type the values instead.
        /// </summary>
        public bool CanContinue { get; set; }

        /// <summary>One entry per document that could not be read.</summary>
        public List<DocumentDiagnosisDto> Diagnostics { get; set; } = [];

        public ExtractedValuesDto Extracted { get; set; } = new();
    }

    public class DocumentDiagnosisDto
    {
        public string DocumentType { get; set; } = string.Empty;
        public string Reason { get; set; } = string.Empty;
        public string Message { get; set; } = string.Empty;
    }

    /// <summary>
    /// Every value the rules could pull out. Nulls are expected and are not errors —
    /// the user fills them in on the confirmation screen.
    /// </summary>
    public class ExtractedValuesDto
    {
        public string? StudentNumber { get; set; }
        public string? StudentName { get; set; }
        public string? Section { get; set; }
        public string? Semester { get; set; }

        public string? LicenseName { get; set; }
        public DateTime? LicenseExpiry { get; set; }

        public string? PlateNumber { get; set; }
        public DateTime? RegistrationExpiry { get; set; }

        public string? PlatePhotoNumber { get; set; }

        /// <summary>
        /// Fields the confirmation screen should draw attention to, and why.
        /// </summary>
        /// <remarks>
        /// Reasons rather than scores: a confidence figure means nothing to the
        /// person holding the receipt, and there is no different action to take at
        /// 0.62 than at 0.71.
        ///
        /// The two reasons need different treatment on screen — a blank the user
        /// must fill in is not the same as a value that was worked out rather than
        /// read, which they only need to glance at.
        /// </remarks>
        public List<FieldFlagDto> FieldsToCheck { get; set; } = [];

        public bool IsFlagged(string field)
            => FieldsToCheck.Any(f => f.Field == field);
    }

    public class FieldFlagDto
    {
        public string Field { get; set; } = string.Empty;

        /// <summary>See <see cref="Enums.FieldFlag"/>.</summary>
        public string Reason { get; set; } = string.Empty;
    }
}
