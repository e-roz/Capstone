using System.Net.Http.Headers;
using System.Net.Http.Json;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    public class EmailService : IEmailService
    {
        private readonly HttpClient _httpClient;
        private readonly IConfiguration _configuration;
        private readonly ILogger<EmailService> _logger;

        public EmailService(HttpClient httpClient, IConfiguration configuration, ILogger<EmailService> logger)
        {
            _httpClient = httpClient;
            _configuration = configuration;
            _logger = logger;
        }

        public async Task SendOtpEmailAsync(string email, string otp, CancellationToken ct = default)
        {
            var html = $"<p>Your AimPark verification code is:</p><h2 style=\"letter-spacing:4px\">{otp}</h2><p>This code expires in 10 minutes. If you didn't request this, you can ignore this email.</p>";

            // OTP delivery is required for the registration flow to proceed, so a failure here
            // must surface to the caller instead of being silently swallowed.
            if (!await SendEmailAsync(email, "Your AimPark verification code", html, ct))
                throw new InvalidOperationException("Failed to send verification email.");
        }

        public async Task SendPasswordResetOtpEmailAsync(string email, string otp, CancellationToken ct = default)
        {
            var html = $"<p>Your AimPark password reset code is:</p><h2 style=\"letter-spacing:4px\">{otp}</h2><p>This code expires in 10 minutes. If you didn't request this, you can ignore this email — your password will not be changed.</p>";

            // Same as OTP delivery for registration: this is required for the flow to proceed,
            // so a failure must surface to the caller instead of being silently swallowed.
            if (!await SendEmailAsync(email, "Your AimPark password reset code", html, ct))
                throw new InvalidOperationException("Failed to send password reset email.");
        }

        public async Task SendRegistrationApprovedEmailAsync(string email, string fullName, CancellationToken ct = default)
        {
            var html = $"<p>Hi {fullName},</p><p>Your AimPark registration has been <strong>approved</strong>. You can now log in and start using the app.</p>";
            await SendEmailAsync(email, "Your AimPark registration was approved", html, ct);
        }

        public async Task SendRegistrationRejectedEmailAsync(string email, string fullName, string reason, CancellationToken ct = default)
        {
            var html = $"<p>Hi {fullName},</p><p>Your AimPark registration was <strong>not approved</strong> for the following reason:</p><blockquote>{reason}</blockquote><p>You may be able to re-apply after the cooldown period shown in the app.</p>";
            await SendEmailAsync(email, "Your AimPark registration was not approved", html, ct);
        }

        // Approval/rejection emails are best-effort notifications: the underlying account-status
        // change has already been saved by the time this runs, so a delivery failure is logged
        // and swallowed rather than thrown, to avoid making the admin action look like it failed.
        private async Task<bool> SendEmailAsync(string to, string subject, string html, CancellationToken ct)
        {
            var apiKey = _configuration["Resend:ApiKey"];
            var fromAddress = _configuration["Resend:FromAddress"] ?? "AimPark <onboarding@resend.dev>";

            var request = new HttpRequestMessage(HttpMethod.Post, "https://api.resend.com/emails")
            {
                Content = JsonContent.Create(new
                {
                    from = fromAddress,
                    to = new[] { to },
                    subject,
                    html
                })
            };
            request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", apiKey);

            var response = await _httpClient.SendAsync(request, ct);

            if (!response.IsSuccessStatusCode)
            {
                var body = await response.Content.ReadAsStringAsync(ct);
                _logger.LogError("Failed to send email to {Email}: {Status} {Body}", to, response.StatusCode, body);
                return false;
            }

            _logger.LogInformation("Email '{Subject}' sent to {Email}", subject, to);
            return true;
        }
    }
}
