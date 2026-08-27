using AimPark.API.DTOs;
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
        /// Optional `source` filters to "Device" (a real RFID scan) or "Manual"
        /// (keyed in from the admin panel).
        /// </summary>
        [HttpGet("rfid-access")]
        public Task<ActionResult<RfidAccessLogListResponse>> ListRfidAccess(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? source = null,
            CancellationToken ct = default)
            => _logService.ListRfidAccessAsync(page, pageSize, source, ct);

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
