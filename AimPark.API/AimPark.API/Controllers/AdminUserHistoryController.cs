using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Everything one account has done, one list per tab on the user's detail
    /// page. Administrator only: it holds payments and violations.
    /// </summary>
    [ApiController]
    [Route("api/admin/users/{userId:guid}/history")]
    [Authorize(Roles = "Admin")]
    public class AdminUserHistoryController : ControllerBase
    {
        private readonly IUserHistoryService _history;

        public AdminUserHistoryController(IUserHistoryService history)
        {
            _history = history;
        }

        /// <summary>The numbers on the tab labels and the overview cards.</summary>
        [HttpGet("summary")]
        public Task<ActionResult<UserHistorySummary>> Summary(Guid userId, CancellationToken ct)
            => _history.GetSummaryAsync(userId, ct);

        /// <summary>Parking sessions, newest first, optionally those that overlapped a window or used one gate.</summary>
        [HttpGet("sessions")]
        public Task<ActionResult<UserHistoryPage<UserSessionItem>>> Sessions(
            Guid userId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20,
            [FromQuery] DateTime? from = null, [FromQuery] DateTime? to = null, [FromQuery] int? gate = null,
            CancellationToken ct = default)
            => _history.GetSessionsAsync(userId, page, pageSize, from, to, gate, ct);

        [HttpGet("violations")]
        public Task<ActionResult<UserHistoryPage<UserViolationItem>>> Violations(
            Guid userId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
            => _history.GetViolationsAsync(userId, page, pageSize, ct);

        /// <summary>Reports this person filed, and reports about a bay they were in around the time.</summary>
        [HttpGet("incidents")]
        public Task<ActionResult<UserIncidents>> Incidents(Guid userId, CancellationToken ct)
            => _history.GetIncidentsAsync(userId, ct);

        [HttpGet("payments")]
        public Task<ActionResult<UserHistoryPage<UserPaymentItem>>> Payments(
            Guid userId, [FromQuery] int page = 1, [FromQuery] int pageSize = 20, CancellationToken ct = default)
            => _history.GetPaymentsAsync(userId, page, pageSize, ct);
    }
}
