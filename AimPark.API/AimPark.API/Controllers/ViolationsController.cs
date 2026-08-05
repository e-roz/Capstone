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

        /// <summary>
        /// Submits an appeal, optionally with supporting photos. Multipart rather
        /// than JSON so evidence can be attached in the same request.
        /// </summary>
        [HttpPost("{violationId:guid}/appeal")]
        [RequestSizeLimit(10 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 10 * 1024 * 1024)]
        public Task<ActionResult<object>> Appeal(Guid violationId, [FromForm] SubmitAppealDto dto, CancellationToken ct)
            => _violationService.SubmitAppealAsync(GetUserId(), violationId, dto, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
