using AimPark.API.Enums;

namespace AimPark.API.DTOs
{
    public class RegistrationStatusResponse
    {
        public RegistrationStep RegistrationStep { get; set; }
        public AccountStatus AccountStatus { get; set; }
        public VerificationStatus VerificationStatus { get; set; }
        public string? RejectionReason { get; set; }
        public DateTime? CanReapplyAt { get; set; }
    }
}
