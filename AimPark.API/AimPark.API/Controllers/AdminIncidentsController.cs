using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/incidents")]
    // Security reads the queue and files reports of their own - "Incident
    // Reporting" is their module in the spec, and a guard who cannot see what
    // has already been reported will report the same broken barrier twice.
    // Deciding one is still an administrator's call; see Review below.
    [Authorize(Roles = "Admin,Security")]
    public class AdminIncidentsController : ControllerBase
    {
        private readonly IIncidentService _incidentService;

        public AdminIncidentsController(IIncidentService incidentService)
        {
            _incidentService = incidentService;
        }

        [HttpGet]
        public Task<ActionResult<IncidentListResponse>> List(
            [FromQuery] string? status = null,
            [FromQuery] string? search = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _incidentService.ListAllAsync(status, search, page, pageSize, ct);

        [HttpGet("{incidentId:guid}")]
        public Task<ActionResult<IncidentDetailResponse>> GetDetail(Guid incidentId, CancellationToken ct)
            => _incidentService.GetDetailForAdminAsync(incidentId, ct);

        // Reviewing is a decision with a consequence - it closes somebody's
        // report and notifies them - so it stays with the administrator, and
        // the panel hides the control rather than letting it 403.
        [Authorize(Roles = "Admin")]
        [HttpPost("{incidentId:guid}/start-review")]
        public Task<ActionResult<object>> StartReview(Guid incidentId, CancellationToken ct)
            => _incidentService.StartReviewAsync(incidentId, GetAdminUserId(), ct);

        [Authorize(Roles = "Admin")]
        [HttpPut("{incidentId:guid}/review")]
        public Task<ActionResult<object>> Review(Guid incidentId, [FromBody] ReviewIncidentDto dto, CancellationToken ct)
            => _incidentService.ReviewAsync(incidentId, GetAdminUserId(), dto, ct);

        // Security's side of a report: add what they found out. Notes only -
        // it cannot change the status, so the decision stays with the admin.
        [Authorize(Roles = "Security")]
        [HttpPost("{incidentId:guid}/follow-ups")]
        [RequestSizeLimit(6 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 6 * 1024 * 1024)]
        public Task<ActionResult<object>> AddFollowUp(
            Guid incidentId, [FromForm] AddIncidentFollowUpDto dto, CancellationToken ct)
            => _incidentService.AddFollowUpAsync(incidentId, GetAdminUserId(), dto, ct);

        // The admin opened the report, so what Security wrote is no longer new.
        [Authorize(Roles = "Admin")]
        [HttpPost("{incidentId:guid}/follow-ups/seen")]
        public Task<ActionResult<object>> MarkFollowUpsSeen(Guid incidentId, CancellationToken ct)
            => _incidentService.MarkFollowUpsSeenAsync(incidentId, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
