using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/incidents")]
    [Authorize]
    public class IncidentsController : ControllerBase
    {
        private readonly IIncidentService _incidentService;

        public IncidentsController(IIncidentService incidentService)
        {
            _incidentService = incidentService;
        }

        [HttpPost]
        [RequestSizeLimit(10 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 10 * 1024 * 1024)]
        public Task<ActionResult<object>> Create([FromForm] CreateIncidentDto dto, CancellationToken ct)
            => _incidentService.CreateAsync(dto, GetUserId(), ct);

        [HttpGet]
        public Task<ActionResult<IncidentListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _incidentService.GetMyIncidentsAsync(GetUserId(), page, pageSize, ct);

        [HttpGet("{incidentId:guid}")]
        public Task<ActionResult<IncidentDetailResponse>> GetDetail(Guid incidentId, CancellationToken ct)
            => _incidentService.GetMyIncidentDetailAsync(GetUserId(), incidentId, ct);

        /// <summary>Corrects a report. Allowed only while still Submitted.</summary>
        [HttpPut("{incidentId:guid}")]
        public Task<ActionResult<object>> Update(
            Guid incidentId, [FromBody] UpdateIncidentDto dto, CancellationToken ct)
            => _incidentService.UpdateMyIncidentAsync(GetUserId(), incidentId, dto, ct);

        /// <summary>Retracts a report. Allowed only while still Submitted.</summary>
        [HttpPost("{incidentId:guid}/withdraw")]
        public Task<ActionResult<object>> Withdraw(Guid incidentId, CancellationToken ct)
            => _incidentService.WithdrawMyIncidentAsync(GetUserId(), incidentId, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
