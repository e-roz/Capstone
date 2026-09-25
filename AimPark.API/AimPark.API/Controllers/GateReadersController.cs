using System.Security.Claims;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The Gate Readers screen: which COM port is which gate's reader, whether
    /// each is connected, the last taps, and the guard's manual open.
    /// </summary>
    /// <remarks>
    /// Site server only. The readers are plugged into the guard PC, so there
    /// is nothing for the cloud to answer — it says so instead of 404ing.
    /// </remarks>
    [ApiController]
    [Route("api/site/gate-readers")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class GateReadersController : ControllerBase
    {
        private readonly UsbGateReaders? _readers;
        private readonly AppDbContext _db;

        public GateReadersController(IServiceProvider services, AppDbContext db)
        {
            _readers = services.GetService<UsbGateReaders>();
            _db = db;
        }

        public class LinkReaderDto
        {
            public Guid DeviceId { get; set; }
        }

        [HttpGet]
        public async Task<ActionResult<object>> Get(CancellationToken ct)
        {
            if (_readers is null) return NotAtGuardPost();

            // Readers that could be linked: live RFID readers on a real gate.
            var devices = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.DeviceType == GateDeviceType.RfidReader && d.Gate >= 1 && !d.IsRevoked)
                .OrderBy(d => d.Gate).ThenBy(d => d.Name)
                .Select(d => new { deviceId = d.Id, name = d.Name, gate = d.Gate })
                .ToListAsync(ct);

            var states = _readers.States();
            var available = UsbGateReaders.AvailablePorts();

            return Ok(new
            {
                ports = available.Select(p =>
                {
                    var state = states.FirstOrDefault(s =>
                        string.Equals(s.Port, p.Port, StringComparison.OrdinalIgnoreCase));
                    return new
                    {
                        port = p.Port,
                        description = p.Description,
                        deviceId = state?.DeviceId,
                        connected = state?.Connected ?? false,
                        error = state?.Error,
                        lastTapAt = state?.LastTapAt
                    };
                })
                // A linked port that has been unplugged still belongs on the
                // list, marked disconnected, so the guard can see which one.
                .Concat(states
                    .Where(s => !available.Any(p =>
                        string.Equals(p.Port, s.Port, StringComparison.OrdinalIgnoreCase)))
                    .Select(s => new
                    {
                        port = s.Port,
                        description = (string?)"Not plugged in",
                        deviceId = (Guid?)s.DeviceId,
                        connected = false,
                        error = s.Error,
                        lastTapAt = s.LastTapAt
                    })),
                readers = devices,
                taps = _readers.RecentTaps()
            });
        }

        /// <summary>Links a port to a reader. Replaces whatever the port was linked to.</summary>
        [HttpPut("{port}")]
        public async Task<ActionResult<object>> Link(string port, [FromBody] LinkReaderDto dto, CancellationToken ct)
        {
            if (_readers is null) return NotAtGuardPost();

            if (await _readers.CheckLinkableAsync(dto.DeviceId, ct) is { } problem)
                return BadRequest(new { message = problem });

            _readers.Bind(port, dto.DeviceId);
            return Ok(new { message = $"{port} linked. Tap a card to try it." });
        }

        [HttpDelete("{port}")]
        public ActionResult<object> Unlink(string port)
        {
            if (_readers is null) return NotAtGuardPost();

            return _readers.Unbind(port)
                ? Ok(new { message = $"{port} unlinked." })
                : NotFound(new { message = $"{port} wasn't linked." });
        }

        /// <summary>Opens the barrier without a card, for when the system can't.</summary>
        [HttpPost("{port}/open")]
        public ActionResult<object> Open(string port)
        {
            if (_readers is null) return NotAtGuardPost();

            var who = User.FindFirst(ClaimTypes.Email)?.Value ?? "a guard";

            return _readers.OpenManually(port, who)
                ? Ok(new { message = "Gate opened." })
                : BadRequest(new { message = $"The reader on {port} isn't connected." });
        }

        private ObjectResult NotAtGuardPost() => BadRequest(new
        {
            message = "Gate readers are plugged into the guard post's PC. Open this screen from the guard post's panel."
        });
    }
}
