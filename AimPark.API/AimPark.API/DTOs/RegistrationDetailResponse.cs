namespace AimPark.API.DTOs
{
    public class RegistrationDetailResponse
    {
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string? PhoneNumber { get; set; }
        public string RegistrationStep { get; set; } = string.Empty;
        public string AccountStatus { get; set; } = string.Empty;
        public string VerificationStatus { get; set; } = string.Empty;
        public string? RejectionReason { get; set; }
        public DateTime? RejectedAt { get; set; }
        public int RejectionCount { get; set; }
        public DateTime? CanReapplyAt { get; set; }
        public VehicleDTO? Vehicle { get; set; }
        public List<DocumentDetailResponse> Documents { get; set; } = [];
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
