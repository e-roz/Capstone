using AimPark.API.Auth;
using AimPark.API.DTOs;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Sync.Site.Cameras;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Globalization;
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
        /// <summary>Plenty for a 640-wide JPEG; stops anything else being streamed in.</summary>
        private const int MaxFrameBytes = 512 * 1024;

        private readonly IAlprService _alpr;
        private readonly CameraFrames? _cameras;

        public GateController(IAlprService alpr, IServiceProvider services)
        {
            _alpr = alpr;
            _cameras = services.GetService<CameraFrames>();
        }

        /// <summary>
        /// The ALPR camera's feed. Call on a steady interval whether or not a
        /// plate is currently visible — see <see cref="SubmitAlprReadingDto"/>.
        /// </summary>
        [HttpPost("alpr-readings")]
        public Task<ActionResult<AlprReadingResponse>> SubmitReading(
            [FromBody] SubmitAlprReadingDto dto, CancellationToken ct)
            => _alpr.SubmitReadingAsync(dto, GetDeviceId(), ct);

        /// <summary>
        /// The ALPR camera's live picture, a JPEG a few times a second, for the
        /// guard's Overview. Site server only: the guard's panel is the only
        /// thing that shows it, and the cloud has no use for the video.
        /// </summary>
        [HttpPost("camera-frame")]
        [RequestSizeLimit(MaxFrameBytes)]
        public async Task<IActionResult> SubmitFrame(CancellationToken ct)
        {
            if (_cameras is null)
                return NotFound(new { message = "Live video goes to the guard post's server, not the cloud." });

            if (User.FindFirst(ApiKeyDefaults.DeviceTypeClaim)?.Value != nameof(GateDeviceType.AlprCamera))
                return StatusCode(StatusCodes.Status403Forbidden,
                    new { message = "This key is not registered to an ALPR camera." });

            using var buffer = new MemoryStream();
            await Request.Body.CopyToAsync(buffer, ct);

            // Every JPEG starts FF D8. Anything else would show as a broken image.
            var jpeg = buffer.ToArray();
            if (jpeg.Length < 4 || jpeg[0] != 0xFF || jpeg[1] != 0xD8)
                return BadRequest(new { message = "Send the frame as a JPEG." });

            var gate = int.Parse(User.FindFirst(ApiKeyDefaults.GateClaim)!.Value, CultureInfo.InvariantCulture);
            _cameras.Put(gate, jpeg);
            return NoContent();
        }

        private Guid GetDeviceId()
            => Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);
    }
}
