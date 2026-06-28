using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
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

        public AuthController(
            IRepository<User> users,
            ITokenService tokenService,
            IRegistrationService registrationService)
        {
            _tokenService = tokenService;
            _users = users;
            _registrationService = registrationService;
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

            return Ok(new LoginResponse
            {
                Message = "Login successful.",
                Token = _tokenService.GenerateToken(user),
                Role = user.Role.ToString(),
                FullName = user.FullName,
                RegistrationStatus = MapStatus(user)
            });
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
