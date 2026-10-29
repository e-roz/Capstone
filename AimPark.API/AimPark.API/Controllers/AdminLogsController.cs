using System.Security.Claims;
using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Sync;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Options;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/logs")]
    // RFID access is the guard's own module - "Access Monitoring" in the spec -
    // so Security reads it here rather than through a second endpoint returning
    // the same rows. The other two logs stay Admin-only: user activity and
    // system errors are administration, not gate work.
    [Authorize(Roles = "Admin,Security")]
    public class AdminLogsController : ControllerBase
    {
        private readonly IAdminLogService _logService;
        private readonly ISlotConfirmationService _slotConfirmation;
        private readonly SiteOptions _site;

        public AdminLogsController(
            IAdminLogService logService,
            ISlotConfirmationService slotConfirmation,
            IOptions<SiteOptions> site)
        {
            _logService = logService;
            _slotConfirmation = slotConfirmation;
            _site = site.Value;
        }

        /// <summary>
        /// The bay the driver confirmed for one session, and every correction
        /// an administrator made to it since.
        /// </summary>
        [HttpGet("parking/{id:guid}/bay-confirm")]
        public async Task<ActionResult<BayConfirmHistoryResponse>> GetBayConfirm(Guid id, CancellationToken ct)
        {
            var history = await _slotConfirmation.GetHistoryAsync(id, ct);
            return history is null
                ? NotFound(new { message = "We could not find that parking session." })
                : Ok(history);
        }

        /// <summary>
        /// Moves a driver's confirmed bay to the one they were really in. Admin
        /// only, with a reason, and in the cloud, which is where confirms live.
        /// A refusal is a 400 with the outcome code in <c>result</c>.
        /// </summary>
        [Authorize(Roles = "Admin")]
        [HttpPost("parking/{id:guid}/correct-bay")]
        public async Task<IActionResult> CorrectBay(
            Guid id, [FromBody] CorrectBayRequest request, CancellationToken ct)
        {
            if (!_site.IsCloud)
                return BadRequest(new
                {
                    result = BayCorrectResult.NotInCloud,
                    message = "Confirmed bays are corrected in the online admin panel, not at the guard post.",
                });

            var adminId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
            var outcome = await _slotConfirmation.CorrectAsync(adminId, id, request, ct);
            return outcome.Result == BayCorrectResult.Corrected
                ? Ok(outcome)
                : BadRequest(new { result = outcome.Result, message = outcome.Message });
        }

        /// <summary>
        /// Vehicle entry and exit as recorded at the gates, most recent first.
        /// Optional filters: `search` (name or plate), `gate`, `vehicleType`,
        /// `visitor` (true for visitors only, false for members only), and an
        /// entry-time range `from` to `to` (both inclusive).
        /// </summary>
        [HttpGet("parking")]
        public Task<ActionResult<RfidAccessLogListResponse>> ListParkingLogs(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? search = null,
            [FromQuery] int? gate = null,
            [FromQuery] VehicleType? vehicleType = null,
            [FromQuery] bool? visitor = null,
            [FromQuery] DateTime? from = null,
            [FromQuery] DateTime? to = null,
            CancellationToken ct = default)
            => _logService.ListRfidAccessAsync(page, pageSize, search, gate, vehicleType, visitor, from, to, ct);

        /// <summary>
        /// Account activity — logins, failed logins, registrations and status
        /// changes — most recent first. Optional `activity` filters to one kind.
        /// </summary>
        [Authorize(Roles = "Admin")]
        [HttpGet("user-activity")]
        public Task<ActionResult<UserActivityLogListResponse>> ListUserActivity(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? activity = null,
            CancellationToken ct = default)
            => _logService.ListUserActivityAsync(page, pageSize, activity, ct);

        /// <summary>
        /// Unhandled server errors, most recent first, as captured by the global
        /// exception handler.
        /// </summary>
        [Authorize(Roles = "Admin")]
        [HttpGet("errors")]
        public Task<ActionResult<SystemErrorLogListResponse>> ListErrors(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _logService.ListErrorsAsync(page, pageSize, ct);
    }
}
