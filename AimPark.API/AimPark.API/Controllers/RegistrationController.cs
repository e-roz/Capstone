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

        [HttpPost("initiate-phone")]
        public Task<ActionResult<SessionResponse>> InitiatePhone([FromBody] InitiatePhoneDto dto, CancellationToken ct)
            => _registrationService.InitiatePhoneAsync(dto, ct);

        [HttpPost("verify-phone")]
        public Task<ActionResult<SessionResponse>> VerifyPhone([FromBody] VerifyOtpDto dto, CancellationToken ct)
            => _registrationService.VerifyPhoneAsync(dto, GetSessionToken(), ct);

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
        public Task<ActionResult<CompleteProfileResponse>> CompleteProfile([FromBody] CompleteProfileDto dto, CancellationToken ct)
            => _registrationService.CompleteProfileAsync(dto, GetSessionToken(), ct);

        [Authorize]
        [HttpPost("vehicle")]
        public Task<ActionResult<object>> RegisterVehicle([FromBody] VehicleDTO dto, CancellationToken ct)
            => _registrationService.RegisterVehicleAsync(dto, GetUserId(), ct);

        [Authorize]
        [HttpPost("documents")]
        [RequestSizeLimit(10 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 10 * 1024 * 1024)]
        public Task<ActionResult<object>> RegisterDocuments([FromForm] DocumentUploadDTO dto, CancellationToken ct)
            => _registrationService.RegisterDocumentsAsync(dto, GetUserId(), ct);

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
