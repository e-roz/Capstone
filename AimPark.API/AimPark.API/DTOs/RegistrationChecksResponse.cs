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
        /// When this was worked out — now, not when the documents were scanned.
        /// The expiry states are recomputed against today on every read, so an
        /// application that sat in the queue for two months does not still claim
        /// a licence is valid.
        /// </summary>
        public DateTime EvaluatedAt { get; set; }
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
