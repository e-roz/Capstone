using System.Linq.Expressions;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using AimPark.API.Sync;
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
        private readonly IFileStorageService? _files;
        public LiveGateController(IServiceProvider services, AppDbContext db)
        {
            _cameras = services.GetService<CameraFrames>();
            _db = db;
            _files = services.GetService<IFileStorageService>();
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

        /// <summary>
        /// Every tap, newest first, a page at a time — the Gate Taps page.
        /// Optional filters: <c>result</c> (entered, exited, denied, manual),
        /// <c>gate</c>, <c>plate</c> (match, mismatch), an inclusive <c>from</c>
        /// to <c>to</c>, and <c>search</c> over name, card and plates.
        /// </summary>
        /// <remarks>
        /// The summary counts follow the date, gate and search filters but not
        /// <c>result</c> or <c>plate</c>: they are the breakdown you pick a
        /// result from, so narrowing to one result must not zero the others.
        /// </remarks>
        [HttpGet("history")]
        public async Task<ActionResult<object>> History(
            [FromQuery] int page = 1,
            [FromQuery] int pageSize = 25,
            [FromQuery] string? result = null,
            [FromQuery] int? gate = null,
            [FromQuery] string? plate = null,
            [FromQuery] DateTime? from = null,
            [FromQuery] DateTime? to = null,
            [FromQuery] string? search = null,
            CancellationToken ct = default)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var scope = _db.Set<GateTapEvent>().AsNoTracking();

            if (gate is int g)
                scope = scope.Where(t => t.Gate == g);
            if (from is DateTime f)
                scope = scope.Where(t => t.At >= f.ToUniversalTime());
            if (to is DateTime u)
                scope = scope.Where(t => t.At <= u.ToUniversalTime());

            if (!string.IsNullOrWhiteSpace(search))
            {
                // Plates are held without spaces or dashes, so a typed one has
                // to be squashed the same way before it can match.
                var term = search.Trim();
                var like = $"%{term}%";
                var plateLike = $"%{term.Replace(" ", "").Replace("-", "")}%";
                scope = scope.Where(t =>
                    (t.PersonName != null && EF.Functions.ILike(t.PersonName, like)) ||
                    (t.RfidTagId != null && EF.Functions.ILike(t.RfidTagId, like)) ||
                    (t.CameraPlate != null && EF.Functions.ILike(t.CameraPlate, plateLike)) ||
                    (t.RegisteredPlates != null && EF.Functions.ILike(t.RegisteredPlates, plateLike)));
            }

            var counts = await scope
                .GroupBy(_ => 1)
                .Select(grp => new
                {
                    Entered = grp.Count(t => t.Opened && t.PersonKind != GateTapPersonKind.Manual && t.Direction == "IN"),
                    Exited = grp.Count(t => t.Opened && t.PersonKind != GateTapPersonKind.Manual && t.Direction == "OUT"),
                    DeniedSerious = grp.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Manual
                        && (t.PersonKind == GateTapPersonKind.Unknown || t.PlateMatches == false)),
                    DeniedRoutine = grp.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Manual
                        && t.PersonKind != GateTapPersonKind.Unknown && t.PlateMatches != false),
                    Manual = grp.Count(t => t.PersonKind == GateTapPersonKind.Manual)
                })
                .FirstOrDefaultAsync(ct);

            var query = scope;

            switch (result?.ToLowerInvariant())
            {
                case "entered":
                    query = query.Where(t => t.Opened && t.PersonKind != GateTapPersonKind.Manual && t.Direction == "IN");
                    break;
                case "exited":
                    query = query.Where(t => t.Opened && t.PersonKind != GateTapPersonKind.Manual && t.Direction == "OUT");
                    break;
                case "denied":
                    query = query.Where(t => !t.Opened && t.PersonKind != GateTapPersonKind.Manual);
                    break;
                case "manual":
                    query = query.Where(t => t.PersonKind == GateTapPersonKind.Manual);
                    break;
            }

            switch (plate?.ToLowerInvariant())
            {
                case "match":
                    query = query.Where(t => t.PlateMatches == true);
                    break;
                case "mismatch":
                    query = query.Where(t => t.PlateMatches == false);
                    break;
            }

            var totalCount = await query.CountAsync(ct);
            var taps = await query
                .OrderByDescending(t => t.At)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(AsRow)
                .ToListAsync(ct);

            var summary = new
            {
                entered = counts?.Entered ?? 0,
                exited = counts?.Exited ?? 0,
                deniedSerious = counts?.DeniedSerious ?? 0,
                deniedRoutine = counts?.DeniedRoutine ?? 0,
                manual = counts?.Manual ?? 0
            };

            return Ok(new { taps, page, pageSize, totalCount, summary });
        }

        // "Serious" is the one place the rule lives, so the rows and the summary
        // counts cannot disagree about which refusals need a look: a card nobody
        // holds, or a plate that is not the card holder's. Anything else the
        // gate refuses (no camera reading, a full lot, a double tap) is routine.
        private static readonly Expression<Func<GateTapEvent, GateTapRow>> AsRow = t => new GateTapRow(
            t.Id, t.At, t.Gate, t.ReaderName, t.Direction, t.Opened, t.Message, t.RfidTagId,
            t.PersonName, t.PersonKind, t.CameraPlate, t.RegisteredPlates, t.PlateMatches, t.HasPhoto,
            !t.Opened && t.PersonKind != GateTapPersonKind.Manual
                && (t.PersonKind == GateTapPersonKind.Unknown || t.PlateMatches == false));

        public record GateTapRow(
            Guid Id, DateTime At, int Gate, string? ReaderName, string Direction, bool Opened,
            string Message, string? RfidTagId, string? PersonName, string PersonKind,
            string? CameraPlate, string? RegisteredPlates, bool? PlateMatches, bool HasPhoto,
            bool Serious);

        [HttpGet("taps/{id:guid}/photo")]
        public async Task<IActionResult> Photo(Guid id, CancellationToken ct)
        {
            var tap = await _db.Set<GateTapEvent>().AsNoTracking()
                .Where(t => t.Id == id && t.HasPhoto)
                .Select(t => new { t.At })
                .FirstOrDefaultAsync(ct);

            var expired = NotFound(new { message = "No photo for this tap. Photos are kept for 30 days." });
            if (tap is null) return expired;

            // In the cloud the photo is the copy the guard PC sent up. It may
            // not have arrived yet (no internet at the guard post), so a miss
            // is "not there yet", not an error.
            if (_cameras is null)
            {
                if (_files is null) return expired;

                var sent = await _files.DownloadAsync(TapPhotos.Bucket, TapPhotos.ObjectPath(id), ct);
                return sent is null
                    ? NotFound(new { message = "This photo has not reached the cloud yet, or it is older than 30 days." })
                    : File(sent, "image/jpeg");
            }

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

        /// <summary>
        /// The gates that have a camera, and whether each is sending right now —
        /// for the Overview's gate picker and its Camera status chip.
        /// </summary>
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

            return Ok(new
            {
                gates = gates.Select(g => new { gate = g, live = _cameras.Latest(g) is not null })
            });
        }

        private ObjectResult NotAtGuardPost() => BadRequest(new
        {
            message = "The live gate log runs on the guard post's server. Open the Overview from the guard post's panel."
        });
    }
}
