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

        /// <summary>Optional <c>state</c> query param: "Free" or "Blocked".</summary>
        [HttpGet]
        public Task<ActionResult<List<RfidCardResponse>>> List([FromQuery] string? state, CancellationToken ct)
            => _adminUserService.ListRfidCardsAsync(state, ct);
    }
}
