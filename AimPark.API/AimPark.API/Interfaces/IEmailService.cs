namespace AimPark.API.Interfaces
{
    public interface IEmailService
    {
        Task SendOtpEmailAsync(string email, string otp, CancellationToken ct = default);
    }
}
