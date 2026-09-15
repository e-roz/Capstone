using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    /// <summary>
    /// The automated verdict on one document submission, and the evidence behind it.
    /// </summary>
    /// <remarks>
    /// One row per submission rather than a column on <see cref="User"/>: a rejected
    /// user can re-apply, and the reviewer needs to see whether the second attempt
    /// actually fixed what the first one failed on.
    ///
    /// The extracted values come from OCR running on the phone. They are evidence
    /// shown to the reviewer, never the decision — every comparison is redone here,
    /// and the admin sees the source images alongside them.
    ///
    /// Raw readings stay here. Anything the rest of the system operates on is copied
    /// out to <see cref="User"/> or <see cref="Vehicle"/> — the plate is read here but
    /// lives on the vehicle, because ALPR reads it at the gate every day.
    /// </remarks>
    public class DocumentVerification
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        /// <summary>
        /// Which vehicle this submission covers, or null when it only re-checks the
        /// person. Adding a second vehicle later means another OR and plate photo,
        /// not another RAF and licence — so the person fields go null on that row.
        /// </summary>
        public Guid? VehicleId { get; set; }
        public Vehicle? Vehicle { get; set; }

        // --- Read from the RAF: is this an enrolled student? ---
        public string? ExtractedStudentNumber { get; set; }
        public string? ExtractedStudentName { get; set; }
        public string? ExtractedSection { get; set; }

        /// <summary>The semester as printed. The usable date lands on User.</summary>
        public string? ExtractedSemester { get; set; }

        // --- Read from the driver's licence: may they legally drive? ---
        public string? ExtractedLicenseName { get; set; }
        public DateTime? ExtractedLicenseExpiry { get; set; }

        /// <summary>
        /// Whether the RAF (or account) name was found printed on the licence.
        /// Null means nothing could be checked; the reviewer decides by eye.
        /// This, not <see cref="ExtractedLicenseName"/>, is what
        /// <see cref="PreScreeningService"/> bases the name-match verdict on —
        /// <see cref="ExtractedLicenseName"/> stays purely for display.
        /// </summary>
        public bool? LicenseNameFound { get; set; }

        // --- Read from the OR: what plate should the gate camera look for? ---
        public string? ExtractedPlateNumber { get; set; }
        public DateTime? ExtractedRegistrationExpiry { get; set; }

        // --- What the user agreed to on the confirmation screen. ---
        //
        // Kept alongside the readings above rather than replacing them. When the two
        // differ the reviewer sees both, so "the machine read X, the person changed
        // it to Y" stays answerable — and an edited value is never quietly passed off
        // as something a document proved.
        public string? ConfirmedStudentNumber { get; set; }
        public string? ConfirmedStudentName { get; set; }
        public string? ConfirmedSection { get; set; }
        public string? ConfirmedSemester { get; set; }
        public string? ConfirmedLicenseName { get; set; }
        public DateTime? ConfirmedLicenseExpiry { get; set; }
        public string? ConfirmedPlateNumber { get; set; }
        public DateTime? ConfirmedRegistrationExpiry { get; set; }

        // --- The comparisons. NotChecked means a value was missing, which is what
        // sends a submission to manual review rather than failing it. ---

        /// <summary>RAF name against licence name. Both name the applicant, unlike
        /// the OR, whose owner is often a family member and is deliberately ignored.</summary>
        public CheckResult NameMatch { get; set; }

        /// <summary>Whether a usable plate was captured. See <see cref="PreScreeningService"/>.</summary>
        public CheckResult PlateMatch { get; set; }

        public CheckResult LicenseValidity { get; set; }
        public CheckResult RegistrationValidity { get; set; }

        /// <summary>Whether the RAF's semester is the current one.</summary>
        public CheckResult EnrollmentValidity { get; set; }

        /// <summary>The overall machine verdict: Passed, Failed, or ManualReview.</summary>
        public VerificationStatus Result { get; set; }

        /// <summary>Plain-language summary of what failed, shown to the reviewer and the user.</summary>
        public string? Notes { get; set; }

        /// <summary>
        /// The raw OCR readings this submission was built from, as JSON keyed by
        /// <see cref="DocumentType"/> name.
        /// </summary>
        /// <remarks>
        /// Kept because the extraction rules are the part of this system most likely
        /// to keep changing, and without the readings there is nothing to change them
        /// against. Every threshold tuned, landmark added or anchor corrected
        /// otherwise costs a trip out to photograph documents again, so rules get
        /// adjusted against a handful of samples and guessed at everywhere else.
        ///
        /// With this column a rule change can be replayed over every submission ever
        /// received, and "why did this one fail" stays answerable months later.
        ///
        /// A few kilobytes per submission. Text and boxes only — the photographs
        /// themselves are files on disk, and nothing here identifies a person beyond
        /// what the extracted columns already hold.
        /// </remarks>
        public string? RawPayloads { get; set; }

        // Set when an admin approves despite the computed checks needing
        // attention — the override, recorded so "the checks flagged this, we
        // let them in anyway" is answerable later.
        public bool WasOverridden { get; set; }
        public Guid? OverriddenByUserId { get; set; }
        public DateTime? OverriddenAt { get; set; }

        /// <summary>The reviewer's own reason for approving over the checks.</summary>
        public string? OverrideNote { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
