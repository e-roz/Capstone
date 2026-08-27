using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// What the guard at the barrier needs: who a card belongs to, and the
    /// spare cards lent to visitors.
    /// </summary>
    /// <remarks>
    /// Admin is allowed everywhere Security is. A supervisor covering the gate
    /// should not have to be handed a second account to do it, and every one of
    /// these actions is already something an admin could do by other means.
    ///
    /// Entry and exit logging is deliberately *not* here — it already lives on
    /// <c>AdminParkingController</c>, which accepts Admin, Security and a gate
    /// device key on the same route. Duplicating it would give the hardware and
    /// the guard two different paths into the same table.
    /// </remarks>
    [ApiController]
    [Route("api/security")]
    [Authorize(Roles = "Admin,Security")]
    public class SecurityController : ControllerBase
    {
        private readonly IVisitorPassService _visitorPasses;

        public SecurityController(IVisitorPassService visitorPasses)
        {
            _visitorPasses = visitorPasses;
        }

        /// <summary>
        /// Who this card belongs to and what should be attached to it.
        /// </summary>
        /// <remarks>
        /// The guard's half of dual-factor verification: the reader proves the
        /// card is genuine, and this tells them which plate ought to be sitting
        /// in front of them so they can check the car matches the card.
        /// </remarks>
        [HttpGet("tags/{rfidTagId}")]
        public Task<ActionResult<TagLookupResponse>> LookupTag(string rfidTagId, CancellationToken ct)
            => _visitorPasses.LookupTagAsync(rfidTagId, ct);

        [HttpPost("visitor-passes")]
        public Task<ActionResult<VisitorPassResponse>> IssuePass(
            [FromBody] IssueVisitorPassDto dto, CancellationToken ct)
            => _visitorPasses.IssueAsync(dto, GetUserId(), ct);

        [HttpGet("visitor-passes")]
        public Task<ActionResult<VisitorPassListResponse>> ListPasses(
            [FromQuery] string? status = null,
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 20,
            CancellationToken ct = default)
            => _visitorPasses.ListAsync(status, page, pageSize, ct);

        /// <summary>Takes a card back, freeing it for the next visitor.</summary>
        [HttpPost("visitor-passes/{passId:guid}/return")]
        public Task<ActionResult<object>> ReturnPass(Guid passId, CancellationToken ct)
            => _visitorPasses.ReturnAsync(passId, ct);

        private Guid GetUserId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
