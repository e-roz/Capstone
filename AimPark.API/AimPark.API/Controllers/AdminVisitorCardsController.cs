using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The cards set aside for lending to visitors. Admin only: Security lends
    /// them out, but deciding which cards are visitor cards is an admin's call.
    /// </summary>
    /// <remarks>
    /// Answered by the cloud. The guard post gets the list in its snapshot and
    /// reads it at the gate; Security sees where each card is through
    /// <c>GET api/security/visitor-cards</c>.
    /// </remarks>
    [ApiController]
    [Route("api/admin/visitor-cards")]
    [Authorize(Roles = "Admin")]
    public class AdminVisitorCardsController : ControllerBase
    {
        private readonly IVisitorCardService _cards;

        public AdminVisitorCardsController(IVisitorCardService cards)
        {
            _cards = cards;
        }

        [HttpGet]
        public Task<ActionResult<List<VisitorCardResponse>>> List(CancellationToken ct)
            => _cards.ListAsync(ct);

        [HttpPost]
        public Task<ActionResult<VisitorCardResponse>> Add([FromBody] AddVisitorCardDto dto, CancellationToken ct)
            => _cards.AddAsync(dto, ct);

        [HttpPost("{rfidTagId}/block")]
        public Task<ActionResult<object>> Block(string rfidTagId, [FromBody] BlockVisitorCardDto? dto, CancellationToken ct)
            => _cards.SetBlockedAsync(rfidTagId, blocked: true, dto?.Note, ct);

        [HttpPost("{rfidTagId}/unblock")]
        public Task<ActionResult<object>> Unblock(string rfidTagId, CancellationToken ct)
            => _cards.SetBlockedAsync(rfidTagId, blocked: false, note: null, ct);

        [HttpDelete("{rfidTagId}")]
        public Task<ActionResult<object>> Remove(string rfidTagId, CancellationToken ct)
            => _cards.RemoveAsync(rfidTagId, ct);
    }
}
