namespace AimPark.API.Interfaces
{
    public interface IEmailService
    {
        Task SendOtpEmailAsync(string email, string otp, CancellationToken ct = default);
        Task SendPasswordResetOtpEmailAsync(string email, string otp, CancellationToken ct = default);
        Task SendRegistrationApprovedEmailAsync(string email, string fullName, CancellationToken ct = default);
        Task SendRegistrationRejectedEmailAsync(string email, string fullName, string reason, CancellationToken ct = default);
    }
}
