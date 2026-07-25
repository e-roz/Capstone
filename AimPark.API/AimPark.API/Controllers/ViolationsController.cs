using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/violations")]
    [Authorize]
    public class ViolationsController : ControllerBase
    {
        private readonly IViolationService _violationService;

        public ViolationsController(IViolationService violationService)
        {
            _violationService = violationService;
        }

        [HttpGet]
        public Task<ActionResult<ViolationListResponse>> List(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _violationService.GetMyViolationsAsync(GetUserId(), page, pageSize, ct);

        [HttpGet("{violationId:guid}")]
        public Task<ActionResult<ViolationDetailResponse>> GetDetail(Guid violationId, CancellationToken ct)
            => _violationService.GetMyViolationDetailAsync(GetUserId(), violationId, ct);

        [HttpPost("{violationId:guid}/appeal")]
        public Task<ActionResult<object>> Appeal(Guid violationId, [FromBody] SubmitAppealDto dto, CancellationToken ct)
            => _violationService.SubmitAppealAsync(GetUserId(), violationId, dto, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
