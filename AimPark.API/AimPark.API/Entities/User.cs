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
    }
}
