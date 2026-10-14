using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// A user renewing their own licence or vehicle registration.
    /// </summary>
    [ApiController]
    [Route("api/renewals")]
    [Authorize]
    public class RenewalsController : ControllerBase
    {
        private readonly IRenewalService _renewals;

        public RenewalsController(IRenewalService renewals)
        {
            _renewals = renewals;
        }

        [HttpPost("scan")]
        [RequestSizeLimit(12 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 12 * 1024 * 1024)]
        public Task<ActionResult<RenewalScanResponse>> Scan([FromForm] RenewalUploadDto dto, CancellationToken ct)
            => _renewals.ScanAsync(dto, GetUserId(), ct);

        [HttpPost("{id:guid}/submit")]
        public Task<ActionResult<object>> Submit(Guid id, [FromBody] SubmitRenewalDto dto, CancellationToken ct)
            => _renewals.SubmitAsync(id, dto, GetUserId(), ct);

        [HttpGet("mine")]
        public Task<ActionResult<List<RenewalResponse>>> GetMine(CancellationToken ct)
            => _renewals.GetMineAsync(GetUserId(), ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
