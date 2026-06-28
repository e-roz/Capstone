using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/registrations")]
    [Authorize(Roles = "Admin")]
    public class AdminRegistrationsController : ControllerBase
    {
        private readonly IAdminRegistrationService _adminRegistrationService;

        public AdminRegistrationsController(IAdminRegistrationService adminRegistrationService)
        {
            _adminRegistrationService = adminRegistrationService;
        }

        [HttpGet("pending")]
        public Task<ActionResult<List<PendingRegistrationResponse>>> GetPending(CancellationToken ct)
            => _adminRegistrationService.GetPendingAsync(ct);

        [HttpGet("{userId:guid}")]
        public Task<ActionResult<RegistrationDetailResponse>> GetDetail(Guid userId, CancellationToken ct)
            => _adminRegistrationService.GetDetailAsync(userId, ct);

        [HttpPost("{userId:guid}/approve")]
        public Task<ActionResult<object>> Approve(Guid userId, CancellationToken ct)
            => _adminRegistrationService.ApproveAsync(userId, GetAdminUserId(), ct);

        [HttpPost("{userId:guid}/reject")]
        public Task<ActionResult<object>> Reject(Guid userId, [FromBody] RejectRegistrationDto dto, CancellationToken ct)
            => _adminRegistrationService.RejectAsync(userId, GetAdminUserId(), dto, ct);

        [HttpPost("{userId:guid}/reset-reapply")]
        public Task<ActionResult<object>> ResetReapply(Guid userId, CancellationToken ct)
            => _adminRegistrationService.ResetReapplyAsync(userId, GetAdminUserId(), ct);

        [HttpPost("{userId:guid}/reset-step")]
        public Task<ActionResult<object>> ResetStep(Guid userId, [FromBody] ResetRegistrationStepDto dto, CancellationToken ct)
            => _adminRegistrationService.ResetStepAsync(userId, GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
