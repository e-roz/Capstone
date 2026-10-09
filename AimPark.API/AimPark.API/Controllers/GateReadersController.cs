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
    /// The Gate Readers screen: which COM port is which gate's reader — or
    /// the ESP-NOW hub, and what each board behind it stands for — whether
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
        private const string HubKind = "hub";
        private const string ReaderKind = "reader";

        private readonly UsbGateReaders? _readers;
        private readonly EspNowHubs? _hubs;
        private readonly AppDbContext _db;
        private readonly IWebHostEnvironment _env;

        public GateReadersController(IServiceProvider services, AppDbContext db, IWebHostEnvironment env)
        {
            _readers = services.GetService<UsbGateReaders>();
            _hubs = services.GetService<EspNowHubs>();
            _db = db;
            _env = env;
        }

        public class LinkReaderDto
        {
            /// <summary>The reader a port stands for. Not used when linking a hub.</summary>
            public Guid? DeviceId { get; set; }

            /// <summary>"reader" (the default) or "hub".</summary>
            public string? Kind { get; set; }
        }

        public class PairDto
        {
            /// <summary>The board asking to join: its MAC as 12 hex digits.</summary>
            public string Id { get; set; } = string.Empty;

            /// <summary>What the hub will call it: G1–G9 for a gate, S1–S9 for a sensor board.</summary>
            public string Node { get; set; } = string.Empty;
        }

        public class LinkNodeDto
        {
            /// <summary>For a gate node (G1, G2): the reader it logs as.</summary>
            public Guid? DeviceId { get; set; }

            /// <summary>For a slot sensor (S1, S2): the slot it watches.</summary>
            public Guid? SlotId { get; set; }
        }

        public class SimulateDto
        {
            public string Line { get; set; } = string.Empty;
        }

        [HttpGet]
        public async Task<ActionResult<object>> Get(CancellationToken ct)
        {
            if (_readers is null || _hubs is null) return NotAtGuardPost();

            // Readers that could be linked: live RFID readers on a real gate.
            var devices = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.DeviceType == GateDeviceType.RfidReader && d.Gate >= 1 && !d.IsRevoked)
                .OrderBy(d => d.Gate).ThenBy(d => d.Name)
                .Select(d => new { deviceId = d.Id, name = d.Name, gate = d.Gate })
                .ToListAsync(ct);

            // Slots a sensor could watch.
            var slots = await _db.Set<ParkingSlot>().AsNoTracking()
                .OrderBy(s => s.Gate).ThenBy(s => s.SlotCode)
                .Select(s => new { slotId = s.Id, slotCode = s.SlotCode, gate = s.Gate, status = s.Status.ToString() })
                .ToListAsync(ct);

            var states = _readers.States();
            var hubs = _hubs.States();
            var available = UsbGateReaders.AvailablePorts();

            static bool Same(string a, string b) => string.Equals(a, b, StringComparison.OrdinalIgnoreCase);

            object Port(string port, string? description)
            {
                var reader = states.FirstOrDefault(s => Same(s.Port, port));
                var hub = hubs.FirstOrDefault(h => Same(h.Port, port));
                return new
                {
                    port,
                    description,
                    kind = hub is not null ? HubKind : reader is not null ? ReaderKind : null,
                    deviceId = reader?.DeviceId,
                    connected = hub?.Connected ?? reader?.Connected ?? false,
                    error = hub?.Error ?? reader?.Error,
                    lastTapAt = reader?.LastTapAt,
                    looksLikeHub = reader?.LooksLikeHub ?? false
                };
            }

            // Only ports with a USB device plugged in are listed. An unplugged
            // port drops off; its link is kept and picks up again when the
            // cable returns. Only the simulated hub, which has no cable, stays.
            var simulated = hubs.Where(h => h.Simulated)
                .Select(h => h.Port)
                .Where(p => !available.Any(a => Same(a.Port, p)));

            return Ok(new
            {
                ports = available.Select(p => Port(p.Port, p.Description))
                    .Concat(simulated.Select(p => Port(p, "Simulated hub"))),
                hubs = hubs.Select(h => new
                {
                    port = h.Port,
                    connected = h.Connected,
                    responding = h.Responding,
                    notTheHub = h.NotTheHub,
                    error = h.Error,
                    lastSeenAt = h.LastSeenAt,
                    simulated = h.Simulated,
                    // The last connection test of the hub and each board, by name ("HUB", "G1").
                    diagnoses = h.Diagnoses.ToDictionary(d => d.Key, d => Diagnosis(d.Value)),
                    // Boards asking to join, to be accepted and named.
                    requests = h.Requests.Select(r => new
                    {
                        id = r.Id,
                        kind = r.Kind == HubNodeKind.Gate ? "gate" : "sensorBoard"
                    }),
                    nodes = h.Nodes.Select(n => new
                    {
                        node = n.Node.Node,
                        // The board's MAC, once the hub has said which board has this name.
                        boardId = h.BoardIds.GetValueOrDefault(n.Node.Node),
                        // A gate node with no reader chosen stands for the gate in its name.
                        gate = HubProtocol.GateOf(n.Node.Node),
                        kind = n.Node.Kind switch
                        {
                            HubNodeKind.Gate => "gate",
                            HubNodeKind.Sensor => "sensor",
                            HubNodeKind.SensorBoard => "sensorBoard",
                            _ => null
                        },
                        boundTo = n.BoundTo,
                        // Behind a hub that isn't there, nothing is known to be up.
                        online = h.Connected && n.Node.Online,
                        lastSeenAt = n.Node.LastSeenAt,
                        wentOfflineAt = n.Node.WentOfflineAt,
                        lastError = n.Node.LastError,
                        lastErrorAt = n.Node.LastErrorAt,
                        lastTapAt = n.Node.LastTapAt,
                        occupied = n.Node.Occupied,
                        distanceCm = n.Node.DistanceCm,
                        // Sensors: unplugged or broken, though its board answers.
                        fault = n.Node.Fault
                    })
                }),
                readers = devices,
                slots,
                taps = _readers.RecentTaps(),
                canSimulate = _env.IsDevelopment()
            });
        }

        /// <summary>
        /// Links a port to a reader, or as an ESP-NOW hub. Replaces whatever
        /// the port was linked to.
        /// </summary>
        [HttpPut("{port}")]
        public async Task<ActionResult<object>> Link(string port, [FromBody] LinkReaderDto dto, CancellationToken ct)
        {
            if (_readers is null || _hubs is null) return NotAtGuardPost();

            if (string.Equals(dto.Kind, HubKind, StringComparison.OrdinalIgnoreCase))
            {
                // The reader holds the port open; it has to let go first.
                _readers.Unbind(port);
                _hubs.Bind(port);
                return Ok(new { message = $"{port} linked as the ESP-NOW hub. Now pick the reader for G1 and G2, and the slot for each sensor on S1 and S2." });
            }

            if (dto.DeviceId is not Guid deviceId)
                return BadRequest(new { message = "Choose the reader this port stands for." });

            if (await _readers.CheckLinkableAsync(deviceId, ct) is { } problem)
                return BadRequest(new { message = problem });

            _hubs.Unbind(port);
            _hubs.ReleaseDevice(deviceId);
            _readers.Bind(port, deviceId);
            return Ok(new { message = $"{port} linked. Tap a card to try it." });
        }

        [HttpDelete("{port}")]
        public ActionResult<object> Unlink(string port)
        {
            if (_readers is null || _hubs is null) return NotAtGuardPost();

            // Not short-circuited: a port is only ever one of the two, but
            // both get the chance to let go of it.
            var unlinked = _hubs.Unbind(port) | _readers.Unbind(port);
            return unlinked
                ? Ok(new { message = $"{port} unlinked." })
                : NotFound(new { message = $"{port} wasn't linked." });
        }

        /// <summary>Opens the barrier without a card, for when the system can't.</summary>
        [HttpPost("{port}/open")]
        public ActionResult<object> Open(string port)
        {
            if (_readers is null) return NotAtGuardPost();

            return _readers.OpenManually(port, CurrentUser())
                ? Ok(new { message = "Gate opened." })
                : BadRequest(new { message = $"The reader on {port} isn't connected." });
        }

        /// <summary>
        /// Says what a board behind the hub stands for: G1/G2 a reader, each
        /// sensor (S1/3) a slot. Catch-all, because a sensor's name has a slash.
        /// </summary>
        [HttpPut("{port}/nodes/{**node}")]
        public async Task<ActionResult<object>> LinkNode(
            string port, string node, [FromBody] LinkNodeDto dto, CancellationToken ct)
        {
            if (_hubs is null) return NotAtGuardPost();

            node = node.ToUpperInvariant();
            var kind = HubProtocol.KindOf(node);
            var problem = kind switch
            {
                HubNodeKind.Gate when dto.DeviceId is null => "Choose the reader this gate logs as.",
                HubNodeKind.Gate => await _hubs.MapGateAsync(port, node, dto.DeviceId, ct),
                HubNodeKind.Sensor when dto.SlotId is null => "Choose the slot this sensor watches.",
                HubNodeKind.Sensor => await _hubs.MapSensorAsync(port, node, dto.SlotId, ct),
                HubNodeKind.SensorBoard => $"{node} is a sensor board. Link each of its sensors ({node}/1, {node}/2 …) to a slot instead.",
                _ => $"{node} isn't a board this server knows."
            };

            if (problem is not null)
                return BadRequest(new { message = problem });

            return Ok(new
            {
                message = kind == HubNodeKind.Gate
                    ? $"{node} linked. Tap a card at it to try it."
                    : $"{node} linked. The slot follows the sensor from now on."
            });
        }

        [HttpDelete("{port}/nodes/{**node}")]
        public async Task<ActionResult<object>> UnlinkNode(string port, string node, CancellationToken ct)
        {
            if (_hubs is null) return NotAtGuardPost();

            node = node.ToUpperInvariant();
            var problem = HubProtocol.KindOf(node) switch
            {
                HubNodeKind.Gate => await _hubs.MapGateAsync(port, node, null, ct),
                HubNodeKind.Sensor => await _hubs.MapSensorAsync(port, node, null, ct),
                _ => $"{node} isn't a board this server knows."
            };

            return problem is null
                ? Ok(new { message = $"{node} unlinked." })
                : BadRequest(new { message = problem });
        }

        /// <summary>
        /// Accepts a board asking to join, and names it. Naming a replacement
        /// with a broken board's name takes over its gate or its slots.
        /// </summary>
        [HttpPost("{port}/pair")]
        public async Task<ActionResult<object>> Pair(string port, [FromBody] PairDto dto)
        {
            if (_hubs is null) return NotAtGuardPost();

            var node = dto.Node.Trim().ToUpperInvariant();
            return await _hubs.PairAsync(port, dto.Id.Trim(), node) is { } problem
                ? BadRequest(new { message = problem })
                : Ok(new
                {
                    message = HubProtocol.GateOf(node) is int gate
                        ? $"Accepted as {node}: it is Gate {gate}. Tap a card at it to try it."
                        : $"Accepted as {node}. Now choose the slot for each of its sensors."
                });
        }

        /// <summary>Removes a board from the hub, e.g. one that broke or is being replaced.</summary>
        [HttpDelete("{port}/boards/{node}")]
        public async Task<ActionResult<object>> Forget(string port, string node)
        {
            if (_hubs is null) return NotAtGuardPost();

            return await _hubs.ForgetAsync(port, node) is { } problem
                ? BadRequest(new { message = problem })
                : Ok(new { message = $"{node.ToUpperInvariant()} removed." });
        }

        /// <summary>The guard's open for a wireless gate.</summary>
        [HttpPost("{port}/nodes/{node}/open")]
        public ActionResult<object> OpenNode(string port, string node)
        {
            if (_hubs is null) return NotAtGuardPost();

            return _hubs.OpenManually(port, node, CurrentUser()) is { } problem
                ? BadRequest(new { message = problem })
                : Ok(new { message = "Gate opened." });
        }

        /// <summary>
        /// Connection test: the hub over USB, then every paired board over the
        /// air, each with its round trip, signal and health.
        /// </summary>
        [HttpPost("{port}/diagnose")]
        public async Task<ActionResult<object>> DiagnoseAll(string port)
        {
            if (_hubs is null) return NotAtGuardPost();

            var results = await _hubs.DiagnoseAllAsync(port);
            if (results is null) return NotFound(new { message = $"{port} isn't linked as a hub." });

            var failed = results.Count(r => !r.Ok);
            var concerns = results.Count(r => r.Ok && r.Problem is not null);
            return Ok(new
            {
                message = failed > 0 ? $"{failed} of {results.Count} didn't answer."
                    : concerns > 0 ? $"All {results.Count} answered; {concerns} need a look."
                    : $"All {results.Count} answered.",
                results = results.Select(Diagnosis)
            });
        }

        /// <summary>Connection test of one board behind the hub. A sensor (S1/3) tests its board.</summary>
        [HttpPost("{port}/diagnose/{**node}")]
        public async Task<ActionResult<object>> DiagnoseNode(string port, string node)
        {
            if (_hubs is null) return NotAtGuardPost();

            var result = await _hubs.DiagnoseAsync(port, node);
            if (result is null) return NotFound(new { message = $"{port} isn't linked as a hub." });

            return Ok(new
            {
                message = result.Ok
                    ? result.Problem ?? $"{result.Node} answered in {result.RoundTripMs} ms."
                    : result.Problem,
                results = new[] { Diagnosis(result) }
            });
        }

        /// <summary>
        /// The hub console: every line over its cable, both ways, oldest first.
        /// <paramref name="after"/> is the last <c>seq</c> already shown.
        /// </summary>
        [HttpGet("{port}/traffic")]
        public ActionResult<object> Traffic(string port, [FromQuery] long after = 0)
        {
            if (_hubs is null) return NotAtGuardPost();

            var lines = _hubs.Traffic(port, after);
            return lines is null
                ? NotFound(new { message = $"{port} isn't linked as a hub." })
                : Ok(new { lines = lines.Select(l => new { seq = l.Seq, at = l.At, @out = l.Out, line = l.Line }) });
        }

        private static object Diagnosis(HubDiagnosis d) => new
        {
            node = d.Node,
            at = d.At,
            ok = d.Ok,
            roundTripMs = d.RoundTripMs,
            values = d.Values,
            problem = d.Problem
        };

        /// <summary>
        /// Development builds only: plays the hub's side, one line at a time,
        /// so the screens can be tried without the boards. Answers with what
        /// the server wrote back, newest first.
        /// </summary>
        [HttpPost("{port}/simulate")]
        public async Task<ActionResult<object>> Simulate(string port, [FromBody] SimulateDto dto, CancellationToken ct)
        {
            if (_hubs is null) return NotAtGuardPost();
            if (!_env.IsDevelopment()) return NotFound();

            var sent = await _hubs.SimulateAsync(port, dto.Line, ct);
            return sent is null
                ? NotFound(new { message = $"{port} isn't linked as a hub." })
                : Ok(new { message = "Sent.", sent });
        }

        private string CurrentUser() => User.FindFirst(ClaimTypes.Email)?.Value ?? "a guard";

        private ObjectResult NotAtGuardPost() => BadRequest(new
        {
            message = "Gate readers are plugged into the guard post's PC. Open this screen from the guard post's panel."
        });
    }
}
