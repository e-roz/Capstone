using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/violations")]
    [Authorize(Roles = "Admin")]
    public class AdminViolationsController : ControllerBase
    {
        private readonly IViolationService _violationService;

        public AdminViolationsController(IViolationService violationService)
        {
            _violationService = violationService;
        }

        [HttpPost]
        public Task<ActionResult<object>> Issue([FromBody] IssueViolationDto dto, CancellationToken ct)
            => _violationService.IssueAsync(dto, GetAdminUserId(), ct);

        /// <summary>
        /// <paramref name="search"/> matches the user's name, student number
        /// or RFID tag; <paramref name="userId"/> narrows to one user's whole
        /// history; <paramref name="ruleId"/> to everyone who broke one rule.
        /// </summary>
        [HttpGet]
        public Task<ActionResult<ViolationListResponse>> List(
            [FromQuery] string? status = null,
            [FromQuery] string? search = null,
            [FromQuery] Guid? userId = null,
            [FromQuery] Guid? ruleId = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _violationService.ListAllAsync(status, search, userId, ruleId, page, pageSize, ct);

        [HttpGet("{violationId:guid}")]
        public Task<ActionResult<ViolationDetailResponse>> GetDetail(Guid violationId, CancellationToken ct)
            => _violationService.GetDetailForAdminAsync(violationId, ct);

        [HttpPut("{violationId:guid}/dismiss")]
        public Task<ActionResult<object>> Dismiss(
            Guid violationId, [FromBody] ViolationReasonDto dto, CancellationToken ct)
            => _violationService.DismissAsync(violationId, GetAdminUserId(), dto, ct);

        /// <summary>Makes the user accountable now, without waiting for the appeal deadline.</summary>
        [HttpPut("{violationId:guid}/accountable")]
        public Task<ActionResult<object>> MakeAccountable(
            Guid violationId, [FromBody] ViolationReasonDto dto, CancellationToken ct)
            => _violationService.MakeAccountableAsync(violationId, GetAdminUserId(), dto, ct);

        [HttpGet("appeals")]
        public Task<ActionResult<ViolationAppealListResponse>> ListAppeals(
            [FromQuery] string? status = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _violationService.ListAppealsAsync(status, page, pageSize, ct);

        [HttpPut("appeals/{appealId:guid}/decide")]
        public Task<ActionResult<object>> DecideAppeal(Guid appealId, [FromBody] DecideAppealDto dto, CancellationToken ct)
            => _violationService.DecideAppealAsync(appealId, GetAdminUserId(), dto, ct);

        private Guid GetAdminUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
