using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The Overview's search box and the profile it opens: one place to start
    /// from a plate, a name or a card and see what the system holds.
    /// </summary>
    [ApiController]
    [Route("api/admin/search")]
    [Authorize(Roles = "Admin")]
    public class AdminSearchController : ControllerBase
    {
        private readonly IInvestigationService _investigation;

        public AdminSearchController(IInvestigationService investigation)
        {
            _investigation = investigation;
        }

        /// <summary>
        /// Matches a name, email, student number, plate or card UID, whichever
        /// way it was typed ("ncd 4417", "04:a1:22:f9").
        /// </summary>
        [HttpGet]
        public async Task<ActionResult<SearchResponse>> Search([FromQuery] string? q, CancellationToken ct)
            => Ok(await _investigation.SearchAsync(q, ct));

        /// <summary>
        /// The profile of one subject. Name exactly one of <c>userId</c>,
        /// <c>visitorPassId</c>, <c>card</c> or <c>plate</c>.
        /// </summary>
        [HttpGet("profile")]
        public async Task<ActionResult<InvestigationProfile>> Profile(
            [FromQuery] Guid? userId, [FromQuery] Guid? visitorPassId,
            [FromQuery] string? card, [FromQuery] string? plate, CancellationToken ct)
        {
            var named = (userId is not null ? 1 : 0) + (visitorPassId is not null ? 1 : 0)
                + (string.IsNullOrWhiteSpace(card) ? 0 : 1) + (string.IsNullOrWhiteSpace(plate) ? 0 : 1);
            if (named != 1)
                return BadRequest(new { message = "Give exactly one of userId, visitorPassId, card or plate." });

            var profile = await _investigation.ProfileAsync(userId, visitorPassId, card, plate, ct);
            return profile is null
                ? NotFound(new { message = "Nothing is recorded for that." })
                : Ok(profile);
        }
    }
}
