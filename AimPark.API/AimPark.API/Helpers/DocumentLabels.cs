namespace AimPark.API.Helpers
{
    /// <summary>
    /// Every printed label the extraction rules anchor on, in one place.
    /// </summary>
    /// <remarks>
    /// The rules live on the server so that a wording change is a redeploy rather
    /// than an app store release. That only pays off if the wordings are findable —
    /// scattering them through the extractor as inline strings means a layout change
    /// turns into a hunt through the code.
    ///
    /// School forms are the volatile ones: layouts differ by campus and shift when
    /// the school updates its system. LTO receipts and licences are national and
    /// change rarely.
    ///
    /// Matching is tolerant, so these are the ideal spelling rather than the exact
    /// characters OCR returns — a real form gave "SY &amp; Tem:" for "SY &amp; Term:".
    /// </remarks>
    public static class DocumentLabels
    {
        /// <summary>Registration and assessment form.</summary>
        public static class SchoolForm
        {
            // Printed as captions beneath the values they describe.
            public const string StudentNumber = "Student No";
            public const string FirstName = "First Name";
            public const string MiddleName = "Middle Name";
            public const string LastName = "Last Name";

            /// <summary>
            /// The financial heading, which spells the term out in full —
            /// "CHARGES for 2026-2027/1st Term". Preferred over the coded header
            /// value because an administrator has to read it.
            /// </summary>
            public const string Charges = "CHARGES for";

            /// <summary>Header field, printed coded as "2627/1T".</summary>
            public const string SchoolYearAndTerm = "SY & Term";

            public const string Program = "Program";
            public const string YearLevel = "Year Level";
            public const string DatePrinted = "Date Printed";
        }

        /// <summary>Philippine driver's licence.</summary>
        public static class License
        {
            public static readonly string[] Name =
                ["Last Name, First Name, Middle Name", "Last Name", "Name"];

            public static readonly string[] Expiry =
                ["Expiration Date", "Expiry Date", "Exp Date", "Expiration"];
        }

        /// <summary>LTO Official Receipt.</summary>
        public static class Receipt
        {
            /// <summary>
            /// The anchor that makes plate extraction safe. Immediately below the
            /// plate sits a File No opening with the same digits, so any rule that
            /// hunts for digits without this captures the wrong value.
            /// </summary>
            public const string PlateNumber = "Plate No";

            /// <summary>
            /// Begins the sentence carrying the expiry. It wraps across several
            /// lines, so the lines must be glued into one stream before searching.
            /// </summary>
            public const string ValidUntil = "valid until";

            public static readonly string[] IssueDate = ["Date"];
        }
    }
}
