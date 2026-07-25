using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/audit-logs")]
    [Authorize(Roles = "Admin")]
    public class AdminAuditLogsController : ControllerBase
    {
        private readonly IAdminAuditLogService _auditLogService;

        public AdminAuditLogsController(IAdminAuditLogService auditLogService)
        {
            _auditLogService = auditLogService;
        }

        /// <summary>
        /// Returns a paginated, most-recent-first list of every admin action taken
        /// (suspend, unsuspend, archive, restore, approve, reject, reset-reapply, reset-step).
        /// Optional `action` query param filters to a single action type.
        /// </summary>
        [HttpGet]
        public Task<ActionResult<AuditLogListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            [FromQuery] string? action = null,
            CancellationToken ct = default)
            => _auditLogService.ListAsync(page, pageSize, action, ct);
    }
}
