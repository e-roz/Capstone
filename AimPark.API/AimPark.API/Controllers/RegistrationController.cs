using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/auth/register")]
    public class RegistrationController : ControllerBase
    {
        private readonly IRegistrationService _registrationService;

        public RegistrationController(IRegistrationService registrationService)
        {
            _registrationService = registrationService;
        }

        [HttpPost("initiate-email")]
        public Task<ActionResult<SessionResponse>> InitiateEmail([FromBody] InitiateEmailDto dto, CancellationToken ct)
            => _registrationService.InitiateEmailAsync(dto, GetSessionToken(), ct);

        [HttpPost("verify-email")]
        public Task<ActionResult<SessionResponse>> VerifyEmail([FromBody] VerifyOtpDto dto, CancellationToken ct)
            => _registrationService.VerifyEmailAsync(dto, GetSessionToken(), ct);

        [HttpPost("resend-otp")]
        public Task<ActionResult<SessionResponse>> ResendOtp([FromBody] ResendOtpDto dto, CancellationToken ct)
            => _registrationService.ResendOtpAsync(dto, GetSessionToken(), ct);

        [HttpPost("complete-profile")]
        public async Task<ActionResult<CompleteProfileResponse>> CompleteProfile([FromBody] CompleteProfileDto dto, CancellationToken ct)
        {
            if (User.Identity?.IsAuthenticated == true && User.HasClaim(c => c.Type == System.Security.Claims.ClaimTypes.NameIdentifier))
            {
                return await _registrationService.CompleteProfileForAuthenticatedUserAsync(dto, GetUserId(), ct);
            }
            return await _registrationService.CompleteProfileAsync(dto, GetSessionToken(), ct);
        }

        /// <summary>
        /// Uploads the documents and returns what the rules read, for the user to
        /// check before anything is committed.
        /// </summary>
        [Authorize]
        [HttpPost("documents/scan")]
        // Four photos captured at full resolution, plus their OCR payloads. The old
        // 10 MB ceiling was sized for downscaled picker images and will reject a
        // legitimate submission now that resolution is what makes the plate readable.
        [RequestSizeLimit(25 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 25 * 1024 * 1024)]
        public Task<ActionResult<ScanResultResponse>> ScanDocuments([FromForm] DocumentUploadDTO dto, CancellationToken ct)
            => _registrationService.ScanDocumentsAsync(dto, GetUserId(), ct);

        /// <summary>
        /// Records the values the user confirmed and completes registration.
        /// </summary>
        [Authorize]
        [HttpPost("documents/confirm")]
        public Task<ActionResult<object>> ConfirmDocuments([FromBody] ConfirmDocumentsDto dto, CancellationToken ct)
            => _registrationService.ConfirmDocumentsAsync(dto, GetUserId(), ct);

        [Authorize]
        [HttpPost("reapply")]
        public Task<ActionResult<ReapplyResponse>> Reapply(CancellationToken ct)
            => _registrationService.ReapplyAsync(GetUserId(), ct);

        [Authorize]
        [HttpGet("status")]
        public Task<ActionResult<RegistrationStatusResponse>> GetStatus(CancellationToken ct)
            => _registrationService.GetStatusAsync(GetUserId(), ct);

        private string? GetSessionToken()
        {
            var authHeader = Request.Headers.Authorization.ToString();
            if (authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
                return authHeader["Bearer ".Length..].Trim();

            return Request.Headers["X-Session-Token"].FirstOrDefault();
        }

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
