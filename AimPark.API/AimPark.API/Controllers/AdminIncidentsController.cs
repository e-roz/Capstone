using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/incidents")]
    [Authorize(Roles = "Admin")]
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

        [HttpPut("{incidentId:guid}/review")]
        public Task<ActionResult<object>> Review(Guid incidentId, [FromBody] ReviewIncidentDto dto, CancellationToken ct)
            => _incidentService.ReviewAsync(incidentId, GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
