using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The pool of physical cards that are no longer tied to a user — either
    /// free to hand to someone new, or blocked because they left circulation
    /// the wrong way (lost, stolen, damaged).
    /// </summary>
    [ApiController]
    [Route("api/admin/rfid-cards")]
    [Authorize(Roles = "Admin")]
    public class AdminRfidCardsController : ControllerBase
    {
        private readonly IAdminUserService _adminUserService;

        public AdminRfidCardsController(IAdminUserService adminUserService)
        {
            _adminUserService = adminUserService;
        }

        /// <summary>
        /// Optional <c>state</c> query param: "Free", "Blocked" or "Assigned".
        /// Cards on someone's account are left out unless
        /// <c>includeAssigned=true</c> (or <c>state=Assigned</c>), so callers
        /// that only want the pool see the same list as before.
        /// </summary>
        [HttpGet]
        public Task<ActionResult<List<RfidCardResponse>>> List(
            [FromQuery] string? state, [FromQuery] bool includeAssigned, CancellationToken ct)
            => _adminUserService.ListRfidCardsAsync(state, includeAssigned, ct);

        /// <summary>Assign and revoke events for one card, newest first.</summary>
        [HttpGet("{tagId}/history")]
        public Task<ActionResult<List<RfidCardHistoryEntry>>> History(string tagId, CancellationToken ct)
            => _adminUserService.GetRfidCardHistoryAsync(tagId, ct);
    }
}
