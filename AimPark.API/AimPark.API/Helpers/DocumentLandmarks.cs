using AimPark.API.DTOs;
using AimPark.API.Enums;

namespace AimPark.API.Helpers
{
    /// <summary>
    /// Whether a photograph is the kind of document it was submitted as.
    /// </summary>
    /// <remarks>
    /// The quality gate in <see cref="OcrCleanup"/> only ever asked "could we read
    /// this". Nothing asked "is this the right piece of paper", so a photograph of
    /// any text at all — a newspaper, a receipt from a shop — passed every automated
    /// step and reached a reviewer looking exactly like a genuine submission, with
    /// the applicant having typed all the values it could not read.
    ///
    /// The answer was already being computed and thrown away: when the extraction
    /// rules look for "Student No" on something that is not a registration form,
    /// they find nothing. This turns that silence into a verdict.
    ///
    /// Deliberately landmark matching rather than a classifier. "The form must carry
    /// at least two of these printed labels" is a rule anyone can read, argue with,
    /// and fix when a campus uses a different template — none of which is true of a
    /// model that reports 83% confidence.
    /// </remarks>
    public static class DocumentLandmarks
    {
        /// <summary>
        /// How many landmarks must be found before the document is accepted as
        /// genuine.
        /// </summary>
        /// <remarks>
        /// Two rather than one, because a single short landmark can be matched by
        /// coincidence; two rather than all, because glare across one corner of an
        /// otherwise perfect form should not reject it. Every list below is chosen so
        /// that any real copy carries all of them and a real photograph loses at most
        /// one or two.
        /// </remarks>
        private const int RequiredHits = 2;

        /// <summary>
        /// Printing that a genuine copy of each document always carries.
        /// </summary>
        /// <remarks>
        /// Long phrases are preferred over short ones. Tolerance scales with length
        /// in <see cref="FuzzyText.ToleranceFor"/>, so a fifteen-character landmark
        /// allows two edits while still being effectively impossible to hit by
        /// accident, whereas a four-character one allows none and fails on ordinary
        /// OCR damage.
        ///
        /// Two document types are absent on purpose. A school ID has no national
        /// layout and is not parsed at all — the reviewer looks at it. A plate photo
        /// carries no labels by definition; it is checked instead by whether the
        /// plate the receipt named appears on it.
        /// </remarks>
        private static readonly Dictionary<DocumentType, string[]> Expected = new()
        {
            [DocumentType.Raf] =
            [
                DocumentLabels.SchoolForm.StudentNumber,
                DocumentLabels.SchoolForm.SchoolYearAndTerm,
                DocumentLabels.SchoolForm.YearLevel,
                DocumentLabels.SchoolForm.Charges,
                DocumentLabels.SchoolForm.Program
            ],

            [DocumentType.License] =
            [
                "DRIVER'S LICENSE",
                "Expiration Date",
                "Republika ng Pilipinas",
                "Nationality",
                "License No"
            ],

            [DocumentType.OfficialReceipt] =
            [
                "OFFICIAL RECEIPT",
                "LAND TRANSPORTATION",
                DocumentLabels.Receipt.PlateNumber,
                "MV File No",
                "Amount Paid"
            ]
        };

        /// <summary>
        /// True when this document type is checked at all.
        /// </summary>
        public static bool AppliesTo(DocumentType type) => Expected.ContainsKey(type);

        /// <summary>
        /// True when enough of the expected printing was found.
        /// </summary>
        /// <remarks>
        /// Types with no landmark list always pass, so an unchecked document is never
        /// rejected by silence in this table.
        /// </remarks>
        public static bool LooksGenuine(IReadOnlyList<OcrLineDto> lines, DocumentType type)
        {
            if (!Expected.TryGetValue(type, out var landmarks))
                return true;

            return CountHits(lines, landmarks) >= RequiredHits;
        }

        /// <summary>
        /// How many of the expected landmarks were found. Exposed so the reviewer can
        /// be told "one of five" rather than only that something was wrong.
        /// </summary>
        public static int CountHits(IReadOnlyList<OcrLineDto> lines, DocumentType type)
            => Expected.TryGetValue(type, out var landmarks) ? CountHits(lines, landmarks) : 0;

        private static int CountHits(IReadOnlyList<OcrLineDto> lines, string[] landmarks)
            => landmarks.Count(landmark => OcrLayout.FindLabel(lines, landmark) is not null);
    }
}
