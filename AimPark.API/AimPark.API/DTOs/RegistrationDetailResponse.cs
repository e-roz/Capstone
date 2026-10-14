namespace AimPark.API.DTOs
{
    public class RegistrationDetailResponse
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Affiliation { get; set; } = string.Empty;
        public string? StudentNumber { get; set; }
        public string? Section { get; set; }

        public string RegistrationStep { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
        public string VerificationStatus { get; set; } = string.Empty;
        public string? RejectionReason { get; set; }
        public DateTime? RejectedAt { get; set; }
        public int RejectionCount { get; set; }
        public DateTime? CanReapplyAt { get; set; }
        public bool IsDeleted { get; set; }
        public DateTime CreatedAt { get; set; }

        /// <summary>Whole days since the last change, worked out as the queue does.</summary>
        public int WaitingDays { get; set; }
        public string? RfidTagId { get; set; }
        public string RfidStatus { get; set; } = string.Empty;
        public DateTime? RfidSuspendedUntil { get; set; }
        // A user may register several vehicles against one RFID card, so the reviewer
        // has to see all of them — a single slot would silently hide the rest.
        public bool IsEBike { get; set; }
        public DateTime? EBikeInspectionDeadline { get; set; }

        /// <summary>The licence expiry on file now, which a renewal replaces.</summary>
        public DateTime? LicenseValidThrough { get; set; }

        /// <summary>A licence or registration renewal is waiting for review.</summary>
        public bool HasPendingRenewal { get; set; }
        public List<VehicleDTO> Vehicles { get; set; } = [];
        public List<DocumentDetailResponse> Documents { get; set; } = [];

        /// <summary>
        /// What the automated checks found. Null when the applicant has not
        /// submitted documents yet — the panel then shows the record alone,
        /// exactly as it did before this existed.
        /// </summary>
        public RegistrationChecksResponse? Checks { get; set; }
    }

    public class DocumentDetailResponse
    {
        public Guid Id { get; set; }
        public string Type { get; set; } = string.Empty;
        public string FileName { get; set; } = string.Empty;
        public string FilePath { get; set; } = string.Empty;
        public DateTime UploadedAt { get; set; }
    }
}
