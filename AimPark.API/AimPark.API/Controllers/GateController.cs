using AimPark.API.Auth;
using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// What gate hardware other than the RFID reader needs to talk to.
    /// Device-key auth only — there is nobody at a keyboard on this path, and
    /// unlike <c>AdminParkingController</c>, nothing here has a manual,
    /// staff-driven equivalent for a guard to fall back on.
    /// </summary>
    [ApiController]
    [Route("api/gate")]
    [Authorize(AuthenticationSchemes = ApiKeyDefaults.AuthenticationScheme, Roles = ApiKeyDefaults.DeviceRole)]
    public class GateController : ControllerBase
    {
        private readonly IAlprService _alpr;

        public GateController(IAlprService alpr)
        {
            _alpr = alpr;
        }

        /// <summary>
        /// The ALPR camera's feed. Call on a steady interval whether or not a
        /// plate is currently visible — see <see cref="SubmitAlprReadingDto"/>.
        /// </summary>
        [HttpPost("alpr-readings")]
        public Task<ActionResult<AlprReadingResponse>> SubmitReading(
            [FromBody] SubmitAlprReadingDto dto, CancellationToken ct)
            => _alpr.SubmitReadingAsync(dto, GetDeviceId(), ct);

        private Guid GetDeviceId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
