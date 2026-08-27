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
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _incidentService.ListAllAsync(status, page, pageSize, ct);

        [HttpGet("{incidentId:guid}")]
        public Task<ActionResult<IncidentDetailResponse>> GetDetail(Guid incidentId, CancellationToken ct)
            => _incidentService.GetDetailForAdminAsync(incidentId, ct);

        // Reviewing is a decision with a consequence - it closes somebody's
        // report and notifies them - so it stays with the administrator, and
        // the panel hides the control rather than letting it 403.
        [Authorize(Roles = "Admin")]
        [HttpPut("{incidentId:guid}/review")]
        public Task<ActionResult<object>> Review(Guid incidentId, [FromBody] ReviewIncidentDto dto, CancellationToken ct)
            => _incidentService.ReviewAsync(incidentId, GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
