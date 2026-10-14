namespace AimPark.API.DTOs
{
    /// <summary>
    /// What the automated checks found, arranged the way a reviewer reads it.
    /// </summary>
    /// <remarks>
    /// This is a projection, not a table dump. The stored rows are one per
    /// submission, but the reviewer thinks in terms of "the person" and "each
    /// vehicle" — and a second-vehicle submission carries no person fields at
    /// all, so replaying rows verbatim would show blank name and licence checks
    /// for someone whose documents passed months ago.
    ///
    /// Nothing here decides anything. A group with six passes means only that
    /// nothing contradicted itself; whether the documents are genuine is still
    /// the reviewer's question, and <see cref="Headlines"/> is phrased to say so.
    /// </remarks>
    public class RegistrationChecksResponse
    {
        /// <summary>Clear, LookCloser, or Unreadable — the banner's tone.</summary>
        public string Verdict { get; set; } = string.Empty;

        /// <summary>One line, already written out: "2 of 6 checks need attention".</summary>
        public string Summary { get; set; } = string.Empty;

        public int Total { get; set; }
        public int NeedsAttention { get; set; }
        public int Unreadable { get; set; }

        /// <summary>The failed and expiring-soon findings, in reviewer's words.</summary>
        public List<string> Headlines { get; set; } = [];

        /// <summary>Null when the applicant has no submission on file at all.</summary>
        public CheckGroupResponse? Person { get; set; }

        public List<CheckGroupResponse> Vehicles { get; set; } = [];

        /// <summary>Only the fields where the applicant's value differs from ours.</summary>
        public List<ValueEditResponse> Edits { get; set; } = [];

        /// <summary>
        /// Every check and every edit as one list, most serious first: identity,
        /// then validity, then edits, then what could not be checked, then passes.
        /// </summary>
        /// <remarks>
        /// Ordered here rather than in the panel so the queue's "top finding" and
        /// the review screen's first row can never disagree.
        /// </remarks>
        public List<FindingResponse> Findings { get; set; } = [];

        /// <summary>The values a reviewer compares against the documents.</summary>
        public RegistrationFactsResponse Facts { get; set; } = new();

        /// <summary>What the phone read, per document, for the document viewer.</summary>
        public List<DocumentReadingResponse> Readings { get; set; } = [];

        /// <summary>
        /// When this was worked out — now, not when the documents were scanned.
        /// The expiry states are recomputed against today on every read, so an
        /// application that sat in the queue for two months does not still claim
        /// a licence is valid.
        /// </summary>
        public DateTime EvaluatedAt { get; set; }
    }

    /// <summary>
    /// One row of the review screen's findings list.
    /// </summary>
    public class FindingResponse
    {
        /// <summary>The check key (NameMatch, …), or Edit.&lt;Field&gt;, or DuplicateUpload.</summary>
        public string Key { get; set; } = string.Empty;

        /// <summary>Identity, Validity, Edited, NotChecked, or Passed.</summary>
        public string Category { get; set; } = string.Empty;

        /// <summary>Danger, Warning, Neutral, or Passed. Never Passed for a NotChecked row.</summary>
        public string Severity { get; set; } = string.Empty;

        /// <summary>One short line: "Name mismatch", "Registration expired".</summary>
        public string Title { get; set; } = string.Empty;

        public string? Detail { get; set; }

        /// <summary>The document to look at: Raf, License, or OfficialReceipt.</summary>
        public string? Document { get; set; }
    }

    /// <summary>
    /// The handful of values the reviewer checks the documents against.
    /// </summary>
    /// <remarks>
    /// Read from the submission, not the account. The account only receives the
    /// student number and section on approval, which is why the review screen
    /// used to have no student number to show.
    /// </remarks>
    public class RegistrationFactsResponse
    {
        public string? SchoolFormName { get; set; }
        public string? LicenseName { get; set; }

        public string? StudentNumber { get; set; }
        public bool StudentNumberTyped { get; set; }
        public string? Section { get; set; }
        public string? Semester { get; set; }

        /// <summary>Everything but the last four characters masked.</summary>
        public string? LicenseNumberMasked { get; set; }

        /// <summary>The phone read nothing, or the applicant changed what it read.</summary>
        public bool LicenseNumberTyped { get; set; }

        public DateTime? LicenseExpiry { get; set; }

        public List<VehicleFactsResponse> Vehicles { get; set; } = [];
    }

    public class VehicleFactsResponse
    {
        public string? PlateNumber { get; set; }
        public DateTime? RegistrationExpiry { get; set; }
    }

    /// <summary>What the phone read off one document, next to what was submitted.</summary>
    public class DocumentReadingResponse
    {
        /// <summary>Raf, License, or OfficialReceipt.</summary>
        public string Document { get; set; } = string.Empty;

        public List<ReadingValueResponse> Values { get; set; } = [];
    }

    public class ReadingValueResponse
    {
        public string Label { get; set; } = string.Empty;

        /// <summary>Null when nothing readable came off the document.</summary>
        public string? Read { get; set; }

        /// <summary>Null when the applicant kept what was read.</summary>
        public string? Submitted { get; set; }
    }

    public class CheckGroupResponse
    {
        public string Title { get; set; } = string.Empty;

        /// <summary>Which documents these checks came from.</summary>
        public string Source { get; set; } = string.Empty;

        public List<CheckItemResponse> Checks { get; set; } = [];
    }

    public class CheckItemResponse
    {
        /// <summary>Stable identifier, e.g. NameMatch. The UI keys off this, not the label.</summary>
        public string Key { get; set; } = string.Empty;

        public string Label { get; set; } = string.Empty;

        /// <summary>Passed, ExpiringSoon, Failed, or NotChecked.</summary>
        public string State { get; set; } = string.Empty;

        /// <summary>The finding in plain words. Null when there is nothing to say.</summary>
        public string? Detail { get; set; }

        /// <summary>The values compared, so the reviewer can see the evidence itself.</summary>
        public List<CheckValueResponse> Values { get; set; } = [];
    }

    public class CheckValueResponse
    {
        public string Label { get; set; } = string.Empty;
        public string Value { get; set; } = string.Empty;
    }

    /// <summary>
    /// A value the applicant typed over what we read.
    /// </summary>
    /// <remarks>
    /// Expected on dates and sections — OCR gets those wrong and correcting them
    /// is the point of the confirmation screen. On a name or a student number it
    /// means the document never proved that value, so those are marked.
    /// </remarks>
    public class ValueEditResponse
    {
        public string Field { get; set; } = string.Empty;

        /// <summary>Null when nothing readable came off the document.</summary>
        public string? Read { get; set; }

        public string Submitted { get; set; } = string.Empty;

        public bool IsIdentity { get; set; }
    }
}
