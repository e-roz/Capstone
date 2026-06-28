using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class EmailService : IEmailService
    {
        private readonly ILogger<EmailService> _logger;

        public EmailService(ILogger<EmailService> logger)
        {
            _logger = logger;
        }

        public Task SendOtpEmailAsync(string email, string otp, CancellationToken ct = default)
        {
            _logger.LogInformation("Stub email OTP sent to {Email}. OTP: {Otp}", email, otp);
            return Task.CompletedTask;
        }
    }
}
