using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class User
    {
        public Guid Id { get; set; }
        public string FullName { get; set; } = string.Empty;

        public string Email { get; set; } = string.Empty;
        public bool IsEmailVerified { get; set; }

        public string? PasswordHash { get; set; }

        public AuthProvider AuthProvider { get; set; }
        public string? ExternalProviderId { get; set; }

        public UserRole Role { get; set; }

        /// <summary>Student, faculty, or staff — decides which documents apply.</summary>
        public Affiliation Affiliation { get; set; } = Affiliation.Student;

        // Read from the RAF. Null on faculty and staff, who have no RAF — which is
        // why Affiliation has to exist: otherwise a blank here has two meanings.
        public string? StudentNumber { get; set; }
        public string? Section { get; set; }

        /// <summary>
        /// End of the enrolled semester, derived from the RAF rather than stored as
        /// its printed text — "is this still current" is then one date comparison.
        /// Null means no expiry, which is the correct answer for faculty and staff.
        /// </summary>
        public DateTime? EnrollmentValidUntil { get; set; }

        public RegistrationStep RegistrationStep { get; set; }
        public AccountStatus AccountStatus { get; set; }

        public VerificationStatus VerificationStatus { get; set; }

        public string? RejectionReason { get; set; }
        public DateTime? RejectedAt { get; set; }
        public int RejectionCount { get; set; }
        public DateTime? CanReapplyAt { get; set; }

        /// <summary>
        /// Documents a reviewer has sent back, as JSON: an array of
        /// <c>{ "type": "OfficialReceipt", "reason": "..." }</c>. Null when
        /// nothing is outstanding.
        /// </summary>
        /// <remarks>
        /// This is the difference between "your application was refused" and
        /// "one photograph was unreadable". Rejection was the only tool a
        /// reviewer had, and it cost the applicant all four documents plus a
        /// cooldown to fix a single blurry receipt — and cost the reviewer a
        /// second full read of three documents they had already approved.
        ///
        /// JSON in one column rather than a table, matching
        /// <c>DocumentVerification.RawPayloads</c>. What is stored is a short
        /// list that is written once, read once and then cleared; nothing joins
        /// or aggregates it, so a table would buy nothing but a migration.
        ///
        /// The account stays <see cref="Enums.AccountStatus.PendingReview"/>
        /// while this is set — the applicant has not been refused, they are
        /// being asked for something. Moving them back to
        /// <see cref="Enums.RegistrationStep.DocumentUpload"/> is what routes
        /// them into the capture flow on their next sign-in, using the same
        /// registration-only token path an unfinished registration already
        /// takes.
        /// </remarks>
        public string? DocumentRetakeJson { get; set; }

        public bool IsFirstLogin { get; set; } = true;

        // When this user accepted the terms and conditions. Recorded rather than
        // assumed, so there is an auditable answer to "did they agree, and when".
        public DateTime? TermsAcceptedAt { get; set; }

        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }

        // Soft-delete fields
        public bool IsDeleted { get; set; } = false;
        public DateTime? DeletedAt { get; set; }

        // Forgot-password OTP fields
        public string? PasswordResetOtpHash { get; set; }
        public DateTime? PasswordResetOtpExpiresAt { get; set; }
        public int PasswordResetOtpAttempts { get; set; } = 0;

        // RFID access fields
        public string? RfidTagId { get; set; }
        public RfidStatus RfidStatus { get; set; } = RfidStatus.Unassigned;

        // Meaningful only when RfidStatus == Suspended: null = permanent/indefinite,
        // a date = temporary suspension, lazily checked/cleared on read.
        public DateTime? RfidSuspendedUntil { get; set; }

        /// <summary>
        /// When a scheduled suspension starts biting. Null means "already in
        /// force", which is how every suspension behaved before appeal windows
        /// existed and how an admin-imposed one still behaves.
        /// </summary>
        /// <remarks>
        /// A violation with a suspension no longer locks the card the instant
        /// it is issued. The card keeps working until this moment, which gives
        /// the user time to read the notification and appeal — appealing a
        /// penalty you are already serving was the complaint that put this
        /// here. Meaningful only when <see cref="RfidStatus"/> is
        /// <c>Suspended</c>, exactly like <see cref="RfidSuspendedUntil"/>.
        ///
        /// Read it through <c>RfidAccess.IsSuspendedNow</c> rather than
        /// directly: a status of Suspended is no longer the same thing as being
        /// refused at the gate.
        /// </remarks>
        public DateTime? RfidSuspendedFrom { get; set; }
    }
}
