namespace AimPark.API.DTOs
{
    /// <summary>The renewed document, sent as a multipart form with what the phone read from it.</summary>
    public class RenewalUploadDto
    {
        public IFormFile? Document { get; set; }

        /// <summary>Serialised OcrPayloadDto, same as at registration.</summary>
        public string? DocumentOcr { get; set; }

        /// <summary>"License" or "OfficialReceipt".</summary>
        public string? Kind { get; set; }

        /// <summary>Required for a registration, which belongs to one vehicle. Ignored for a licence.</summary>
        public Guid? VehicleId { get; set; }
    }

    public class RenewalScanResponse
    {
        public Guid RenewalId { get; set; }

        public DateTime? ExtractedExpiry { get; set; }

        /// <summary>False while a retake would still help. Retakes are unlimited: the user already has an account.</summary>
        public bool CanContinue { get; set; }

        public List<DocumentDiagnosisDto> Diagnostics { get; set; } = [];
    }

    public class SubmitRenewalDto
    {
        /// <summary>The expiry the user agreed to. Required.</summary>
        public DateTime? Expiry { get; set; }
    }

    /// <summary>A renewal as the user's own app sees it.</summary>
    public class RenewalResponse
    {
        public Guid Id { get; set; }
        public string Kind { get; set; } = string.Empty;
        public Guid? VehicleId { get; set; }
        public string? PlateNumber { get; set; }
        public string Status { get; set; } = string.Empty;
        public DateTime? NewExpiry { get; set; }
        public string? RejectReason { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    /// <summary>A renewal as the admin's queue sees it.</summary>
    public class AdminRenewalResponse
    {
        public Guid Id { get; set; }
        public Guid UserId { get; set; }
        public string FullName { get; set; } = string.Empty;
        public string Email { get; set; } = string.Empty;
        public string Kind { get; set; } = string.Empty;
        public Guid? VehicleId { get; set; }
        public string? PlateNumber { get; set; }
        public string Status { get; set; } = string.Empty;

        /// <summary>The expiry on file now, before this renewal.</summary>
        public DateTime? CurrentExpiry { get; set; }
        public DateTime? ExtractedExpiry { get; set; }
        public DateTime? NewExpiry { get; set; }

        public string FileName { get; set; } = string.Empty;
        public string FileUrl { get; set; } = string.Empty;

        public string? RejectReason { get; set; }
        public string? ReviewedByName { get; set; }
        public DateTime? ReviewedAt { get; set; }
        public DateTime CreatedAt { get; set; }
    }

    public class RejectRenewalDto
    {
        public string? Reason { get; set; }
    }
}
