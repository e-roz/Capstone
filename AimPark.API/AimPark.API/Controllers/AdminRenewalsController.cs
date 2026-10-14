using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The admin's queue of renewed licences and registrations.
    /// </summary>
    [ApiController]
    [Route("api/admin/renewals")]
    [Authorize(Roles = "Admin")]
    public class AdminRenewalsController : ControllerBase
    {
        private readonly IRenewalService _renewals;

        public AdminRenewalsController(IRenewalService renewals)
        {
            _renewals = renewals;
        }

        [HttpGet]
        public Task<ActionResult<List<AdminRenewalResponse>>> Get([FromQuery] string? status, CancellationToken ct)
            => _renewals.GetForAdminAsync(status, ct);

        [HttpPost("{id:guid}/approve")]
        public Task<ActionResult<object>> Approve(Guid id, CancellationToken ct)
            => _renewals.ApproveAsync(id, GetAdminUserId(), ct);

        [HttpPost("{id:guid}/reject")]
        public Task<ActionResult<object>> Reject(Guid id, [FromBody] RejectRenewalDto dto, CancellationToken ct)
            => _renewals.RejectAsync(id, GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
