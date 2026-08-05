using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Google.Apis.Auth;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Google;
using Microsoft.AspNetCore.Authentication.MicrosoftAccount;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {
        private readonly ITokenService _tokenService;
        private readonly IRepository<User> _users;
        private readonly IRegistrationService _registrationService;
        private readonly IConfiguration _config;
        private readonly IOtpService _otpService;
        private readonly IEmailService _emailService;

        public AuthController(
            IRepository<User> users,
            ITokenService tokenService,
            IRegistrationService registrationService,
            IConfiguration config,
            IOtpService otpService,
            IEmailService emailService)
        {
            _tokenService = tokenService;
            _users = users;
            _registrationService = registrationService;
            _config = config;
            _otpService = otpService;
            _emailService = emailService;
        }

        [HttpPost("login")]
        public async Task<ActionResult<LoginResponse>> Login([FromBody] LoginDTO dto, CancellationToken ct)
        {
            if (ValidationHelper.HasEmptyFields(dto.Email, dto.Password))
                return BadRequest(new LoginResponse { Message = "All fields are required." });

            var email = IdentifierNormalizer.NormalizeEmail(dto.Email);
            var user = await _users.FindAsync(u => u.Email == email, ct);

            if (user is null || user.PasswordHash is null ||
                !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            {
                return Unauthorized(new LoginResponse { Message = "Invalid credentials." });
            }

            if (user.IsDeleted)
            {
                return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                {
                    Message = "This account has been deleted. Please contact admin."
                });
            }

            if (user.RegistrationStep != RegistrationStep.Completed)
            {
                return Ok(new LoginResponse
                {
                    Message = "Please complete your registration.",
                    Token = _tokenService.GenerateToken(user, registrationOnly: true),
                    Role = user.Role.ToString(),
                    FullName = user.FullName,
                    RegistrationStatus = MapStatus(user)
                });
            }

            switch (user.AccountStatus)
            {
                case AccountStatus.PendingReview:
                    return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                    {
                        Message = "Your account is waiting for admin approval.",
                        RegistrationStatus = MapStatus(user)
                    });

                case AccountStatus.Rejected:
                    return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                    {
                        // No formatted date here — CanReapplyAt is returned as a
                        // real timestamp below, so the client renders it in the
                        // user's own locale and timezone. Interpolating it here
                        // put a raw ISO-8601 string in front of the user.
                        Message = user.CanReapplyAt is not null && DateTime.UtcNow < user.CanReapplyAt
                            ? "Your registration was rejected. You may re-apply once the waiting period has passed."
                            : "Your registration was rejected.",
                        RejectionReason = user.RejectionReason,
                        CanReapplyAt = user.CanReapplyAt,
                        RegistrationStatus = MapStatus(user)
                    });

                case AccountStatus.Suspended:
                    return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                    {
                        Message = "Your account has been suspended. Please contact admin.",
                        RegistrationStatus = MapStatus(user)
                    });
            }

            return Ok(new LoginResponse
            {
                Message = "Login successful.",
                Token = _tokenService.GenerateToken(user),
                Role = user.Role.ToString(),
                FullName = user.FullName,
                RegistrationStatus = MapStatus(user)
            });
        }

        [HttpPost("google/signin")]
        public async Task<ActionResult<LoginResponse>> GoogleSignIn([FromBody] GoogleSignInDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.IdToken))
                return BadRequest(new LoginResponse { Message = "Google ID token is required." });

            var clientId = _config["GoogleAuth:ClientId"];
            if (string.IsNullOrWhiteSpace(clientId))
                return StatusCode(StatusCodes.Status500InternalServerError, new LoginResponse { Message = "Google authentication is not configured." });

            GoogleJsonWebSignature.Payload payload;
            try
            {
                var settings = new GoogleJsonWebSignature.ValidationSettings
                {
                    Audience = new[] { clientId }
                };
                payload = await GoogleJsonWebSignature.ValidateAsync(dto.IdToken, settings);
            }
            catch (Exception ex)
            {
                Console.WriteLine($"[GoogleSignIn] Token validation failed: {ex.GetType().Name}: {ex.Message}");
                return Unauthorized(new LoginResponse { Message = "Invalid or expired Google token. Please sign in again." });
            }

            var email = IdentifierNormalizer.NormalizeEmail(payload.Email);
            var externalId = payload.Subject;
            var fullName = payload.Name;

            var user = await _users.FindAsync(u => u.Email == email, ct);

            if (user is not null)
            {
                // Conflict: existing local account, do NOT auto-link
                if (user.AuthProvider == AuthProvider.Local && user.PasswordHash is not null)
                {
                    return Conflict(new LoginResponse
                    {
                        Message = "This email is already registered. Please log in with your password instead."
                    });
                }

                if (user.IsDeleted)
                    return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                    {
                        Message = "This account has been deleted. Please contact admin."
                    });

                // Returning Google user: gate on account status first
                switch (user.AccountStatus)
                {
                    case AccountStatus.PendingReview when user.RegistrationStep == RegistrationStep.Completed:
                        return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                        {
                            Message = "Your account is waiting for admin approval.",
                            RegistrationStatus = MapStatus(user)
                        });

                    case AccountStatus.Rejected:
                        return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                        {
                            Message = user.CanReapplyAt is not null && DateTime.UtcNow < user.CanReapplyAt
                                ? $"Your registration was rejected. You may re-apply after {user.CanReapplyAt:O}."
                                : "Your registration was rejected.",
                            RejectionReason = user.RejectionReason,
                            CanReapplyAt = user.CanReapplyAt,
                            RegistrationStatus = MapStatus(user)
                        });

                    case AccountStatus.Suspended:
                        return StatusCode(StatusCodes.Status403Forbidden, new LoginResponse
                        {
                            Message = "Your account has been suspended. Please contact admin.",
                            RegistrationStatus = MapStatus(user)
                        });
                }

                // Registration incomplete — send back a registration-only JWT so the app
                // can route to the correct step without re-entering credentials.
                if (user.RegistrationStep != RegistrationStep.Completed)
                {
                    return Ok(new LoginResponse
                    {
                        Message = "Please complete your registration.",
                        Token = _tokenService.GenerateToken(user, registrationOnly: true),
                        Role = user.Role.ToString(),
                        FullName = user.FullName,
                        RegistrationStatus = MapStatus(user)
                    });
                }

                // Fully registered & active — issue full JWT
                return Ok(new LoginResponse
                {
                    Message = "Login successful.",
                    Token = _tokenService.GenerateToken(user),
                    Role = user.Role.ToString(),
                    FullName = user.FullName,
                    RegistrationStatus = MapStatus(user)
                });
            }

            // New Google user — create the account, skip email OTP, enter at ProfileSetup
            var now = DateTime.UtcNow;
            var newUser = new User
            {
                Id = Guid.NewGuid(),
                FullName = fullName?.Trim() ?? string.Empty,
                Email = email,
                IsEmailVerified = true,
                PasswordHash = null,
                AuthProvider = AuthProvider.Google,
                ExternalProviderId = externalId,
                Role = UserRole.User,
                RegistrationStep = RegistrationStep.ProfileSetup,
                AccountStatus = AccountStatus.PendingReview,
                VerificationStatus = VerificationStatus.NotStarted,
                IsFirstLogin = true,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _users.AddAsync(newUser, ct);
            await _users.SaveAsync(ct);

            return Ok(new LoginResponse
            {
                Message = "Google sign-in successful. Please complete your profile.",
                Token = _tokenService.GenerateToken(newUser, registrationOnly: true),
                Role = newUser.Role.ToString(),
                FullName = newUser.FullName,
                RegistrationStatus = MapStatus(newUser)
            });
        }

        [HttpPost("forgot-password")]
        public async Task<ActionResult<object>> ForgotPassword([FromBody] ForgotPasswordDto dto, CancellationToken ct)
        {
            var email = IdentifierNormalizer.NormalizeEmail(dto.Email);
            var user = await _users.FindAsync(u => u.Email == email, ct);

            // Only Local-auth accounts have a password to reset. The response message is the
            // same either way, so it never reveals whether an email is registered.
            if (user is not null && !user.IsDeleted && user.AuthProvider == AuthProvider.Local)
            {
                var otp = _otpService.GenerateOtp();
                user.PasswordResetOtpHash = _otpService.HashOtp(otp);
                user.PasswordResetOtpExpiresAt = DateTime.UtcNow.Add(_otpService.OtpExpiry);
                user.PasswordResetOtpAttempts = 0;
                user.UpdatedAt = DateTime.UtcNow;

                _users.Update(user);
                await _users.SaveAsync(ct);

                await _emailService.SendPasswordResetOtpEmailAsync(user.Email, otp, ct);
            }

            return Ok(new { message = "If an account with that email exists, a password reset code has been sent." });
        }

        [HttpPost("reset-password")]
        public async Task<ActionResult<object>> ResetPassword([FromBody] ResetPasswordDto dto, CancellationToken ct)
        {
            if (ValidationHelper.HasEmptyFields(dto.Email, dto.Otp, dto.NewPassword))
                return BadRequest(new { message = "All fields are required." });

            var email = IdentifierNormalizer.NormalizeEmail(dto.Email);
            var user = await _users.FindAsync(u => u.Email == email, ct);

            if (user is null || user.PasswordResetOtpHash is null || user.PasswordResetOtpExpiresAt is null)
                return BadRequest(new { message = "Invalid or expired reset code." });

            if (DateTime.UtcNow > user.PasswordResetOtpExpiresAt)
                return BadRequest(new { message = "Reset code has expired. Please request a new one." });

            if (user.PasswordResetOtpAttempts >= _otpService.MaxAttempts)
                return BadRequest(new { message = "Too many attempts. Please request a new reset code." });

            if (!_otpService.VerifyOtp(dto.Otp, user.PasswordResetOtpHash))
            {
                user.PasswordResetOtpAttempts++;
                _users.Update(user);
                await _users.SaveAsync(ct);
                return BadRequest(new { message = "Incorrect code." });
            }

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.NewPassword, workFactor: 12);
            user.PasswordResetOtpHash = null;
            user.PasswordResetOtpExpiresAt = null;
            user.PasswordResetOtpAttempts = 0;
            user.UpdatedAt = DateTime.UtcNow;

            _users.Update(user);
            await _users.SaveAsync(ct);

            return Ok(new { message = "Password reset successful. You can now log in with your new password." });
        }

        [HttpGet("external/google")]
        public IActionResult GoogleLogin()
            => Challenge(new AuthenticationProperties { RedirectUri = "/api/auth/external/google/callback" }, GoogleDefaults.AuthenticationScheme);

        [HttpGet("external/google/callback")]
        public Task<ActionResult<OAuthCallbackResponse>> GoogleCallback(CancellationToken ct)
            => AuthenticateExternalAsync(GoogleDefaults.AuthenticationScheme, AuthProvider.Google, ct);

        [HttpGet("external/microsoft")]
        public IActionResult MicrosoftLogin()
            => Challenge(new AuthenticationProperties { RedirectUri = "/api/auth/external/microsoft/callback" }, MicrosoftAccountDefaults.AuthenticationScheme);

        [HttpGet("external/microsoft/callback")]
        public Task<ActionResult<OAuthCallbackResponse>> MicrosoftCallback(CancellationToken ct)
            => AuthenticateExternalAsync(MicrosoftAccountDefaults.AuthenticationScheme, AuthProvider.Microsoft, ct);

        private async Task<ActionResult<OAuthCallbackResponse>> AuthenticateExternalAsync(
            string scheme,
            AuthProvider provider,
            CancellationToken ct)
        {
            var result = await HttpContext.AuthenticateAsync(scheme);
            if (!result.Succeeded)
                return BadRequest(new OAuthCallbackResponse { Message = "External authentication failed." });

            var principal = result.Principal!;
            var email = principal.FindFirstValue(ClaimTypes.Email)
                ?? principal.FindFirstValue("email");
            var externalId = principal.FindFirstValue(ClaimTypes.NameIdentifier)
                ?? principal.FindFirstValue("sub");
            var fullName = principal.FindFirstValue(ClaimTypes.Name)
                ?? principal.FindFirstValue("name");

            if (string.IsNullOrWhiteSpace(email) || string.IsNullOrWhiteSpace(externalId))
            {
                return BadRequest(new OAuthCallbackResponse
                {
                    Message = "OAuth provider did not return required claims."
                });
            }

            return await _registrationService.HandleOAuthCallbackAsync(
                provider,
                email,
                externalId,
                fullName,
                ct);
        }

        private static RegistrationStatusResponse MapStatus(User user) => new()
        {
            RegistrationStep = user.RegistrationStep,
            AccountStatus = user.AccountStatus,
            VerificationStatus = user.VerificationStatus,
            RejectionReason = user.RejectionReason,
            CanReapplyAt = user.CanReapplyAt
        };
    }
}
