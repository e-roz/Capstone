using System.Linq.Expressions;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Sync.Site.Cameras;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The guard's Overview: today's taps as they happen, the photo kept for
    /// each, and the live picture from each gate's camera.
    /// </summary>
    /// <remarks>
    /// The live log and the camera are site server only, like
    /// <see cref="GateReadersController"/>: the video never leaves the guard PC.
    /// The panel polls these once a second, so the tap list takes a
    /// <c>since</c> and answers with only what's new. The full history also
    /// answers in the cloud, which receives every tap through the outbox; the
    /// photos stay on the guard PC.
    /// </remarks>
    [ApiController]
    [Route("api/site/live-gate")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class LiveGateController : ControllerBase
    {
        private readonly CameraFrames? _cameras;
        private readonly AppDbContext _db;
        public LiveGateController(IServiceProvider services, AppDbContext db)
        {
            _cameras = services.GetService<CameraFrames>();
            _db = db;
        }

        /// <summary>How many taps the Overview's live log shows.</summary>
        private const int LiveCount = 5;

        /// <summary>
        /// The Overview's newest taps today, newest first. With
        /// <paramref name="since"/>, only the ones after it, so the once-a-second
        /// poll is usually empty.
        /// </summary>
        [HttpGet("taps")]
        public async Task<ActionResult<object>> Taps([FromQuery] DateTime? since, CancellationToken ct)
        {
            if (_cameras is null) return NotAtGuardPost();

            // "Today" is the guard post's day, not UTC's: at UTC+8 the UTC day
            // turns over at 8 in the morning.
            var startOfToday = DateTime.Now.Date.ToUniversalTime();
            var from = since is DateTime s && s.ToUniversalTime() > startOfToday
                ? s.ToUniversalTime()
                : startOfToday;

            var taps = await _db.Set<GateTapEvent>().AsNoTracking()
                .Where(t => t.At > from)
                .OrderByDescending(t => t.At)
                .Take(LiveCount)
                .Select(AsRow)
                .ToListAsync(ct);

            return Ok(new { taps });
        }

        /// <summary>Every tap, newest first, a page at a time — Access Monitoring's Gate taps tab.</summary>
        [HttpGet("history")]
        public async Task<ActionResult<object>> History(
            [FromQuery] int page = 1, [FromQuery] int pageSize = 25, CancellationToken ct = default)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<GateTapEvent>().AsNoTracking();
            var totalCount = await query.CountAsync(ct);
            var taps = await query
                .OrderByDescending(t => t.At)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(AsRow)
                .ToListAsync(ct);

            return Ok(new { taps, page, pageSize, totalCount });
        }

        private static readonly Expression<Func<GateTapEvent, GateTapRow>> AsRow = t => new GateTapRow(
            t.Id, t.At, t.Gate, t.ReaderName, t.Direction, t.Opened, t.Message, t.RfidTagId,
            t.PersonName, t.PersonKind, t.CameraPlate, t.RegisteredPlates, t.PlateMatches, t.HasPhoto);

        public record GateTapRow(
            Guid Id, DateTime At, int Gate, string? ReaderName, string Direction, bool Opened,
            string Message, string? RfidTagId, string? PersonName, string PersonKind,
            string? CameraPlate, string? RegisteredPlates, bool? PlateMatches, bool HasPhoto);

        [HttpGet("taps/{id:guid}/photo")]
        public async Task<IActionResult> Photo(Guid id, CancellationToken ct)
        {
            var tap = await _db.Set<GateTapEvent>().AsNoTracking()
                .Where(t => t.Id == id && t.HasPhoto)
                .Select(t => new { t.At })
                .FirstOrDefaultAsync(ct);

            var expired = NotFound(new { message = "No photo for this tap. Photos are kept for 30 days." });
            if (tap is null) return expired;

            // Photos never leave the guard PC.
            if (_cameras is null)
                return NotFound(new { message = "Tap photos are kept on the guard post's PC. Open this from the guard post's panel." });

            var path = CameraFrames.PhotoPath(id, tap.At);
            return System.IO.File.Exists(path) ? PhysicalFile(path, "image/jpeg") : expired;
        }

        /// <summary>The gate's newest camera frame, or 204 when the camera has gone quiet.</summary>
        [HttpGet("camera/{gate:int}")]
        public IActionResult Camera(int gate)
        {
            if (_cameras is null) return NotAtGuardPost();

            var frame = _cameras.Latest(gate);
            if (frame is null) return NoContent();

            Response.Headers.CacheControl = "no-store";
            return File(frame.Jpeg, "image/jpeg");
        }

        /// <summary>The gates that have a camera, for the Overview's gate picker.</summary>
        [HttpGet("cameras")]
        public async Task<ActionResult<object>> Cameras(CancellationToken ct)
        {
            if (_cameras is null) return NotAtGuardPost();

            var gates = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.DeviceType == GateDeviceType.AlprCamera && d.Gate >= 1 && !d.IsRevoked)
                .Select(d => d.Gate)
                .Distinct()
                .OrderBy(g => g)
                .ToListAsync(ct);

            return Ok(new { gates });
        }

        private ObjectResult NotAtGuardPost() => BadRequest(new
        {
            message = "The live gate log runs on the guard post's server. Open the Overview from the guard post's panel."
        });
    }
}
