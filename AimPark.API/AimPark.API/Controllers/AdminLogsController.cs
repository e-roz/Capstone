using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

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

        public AdminLogsController(IAdminLogService logService)
        {
            _logService = logService;
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
