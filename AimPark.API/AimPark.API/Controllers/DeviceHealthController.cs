using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Sync;
using AimPark.API.Sync.Site;
using AimPark.API.Sync.Site.Cameras;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Every piece of hardware the guard post depends on, in one list: the
    /// hub and the boards behind it, the USB readers, each gate's camera, and
    /// the link to the cloud. For the Overview (Security) and the dashboard
    /// (Admin).
    /// </summary>
    /// <remarks>
    /// Site server only, like <see cref="GateReadersController"/>: it reports
    /// what is plugged into this PC. Each row says what the device is, what it
    /// stands for, whether it is up, when it was last heard from, and the last
    /// thing that went wrong. What to do about it is the panel's to say.
    ///
    /// <c>dependsOn</c> names the row a device can't work without — a gate
    /// node behind a hub that has been unplugged is down because of the hub,
    /// and the fix is the hub's.
    /// </remarks>
    [ApiController]
    [Route("api/site/device-health")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class DeviceHealthController : ControllerBase
    {
        /// <summary>A node error older than this is history, not a problem.</summary>
        private static readonly TimeSpan RecentError = TimeSpan.FromMinutes(10);

        private readonly IServiceProvider _services;
        private readonly SiteOptions _options;
        private readonly AppDbContext _db;

        public DeviceHealthController(IServiceProvider services, IOptions<SiteOptions> options, AppDbContext db)
        {
            _services = services;
            _options = options.Value;
            _db = db;
        }

        public record DeviceHealth(
            string Id,
            string Name,
            string Kind,
            string? BoundTo,
            bool Bound,
            bool Online,
            DateTime? LastSeenAt,
            string? LastError,
            DateTime? LastErrorAt,
            string? DependsOn = null,
            string? Detail = null,
            bool? Occupied = null,
            int? DistanceCm = null);

        [HttpGet]
        public async Task<ActionResult<object>> Get(CancellationToken ct)
        {
            var readers = _services.GetService<UsbGateReaders>();
            var hubs = _services.GetService<EspNowHubs>();
            var cameras = _services.GetService<CameraFrames>();
            var sync = _services.GetService<SiteSyncStatus>();

            if (!_options.IsSite || readers is null || hubs is null || cameras is null || sync is null)
                return BadRequest(new
                {
                    message = "Device health is read from the guard post's server. Open the panel from the guard post's PC."
                });

            var devices = await _db.Set<GateDevice>().AsNoTracking()
                .Where(d => d.DeviceType != GateDeviceType.SiteServer)
                .Select(d => new { d.Id, d.Name, d.Gate, d.DeviceType, d.IsRevoked, d.LastSeenAt })
                .ToDictionaryAsync(d => d.Id, ct);

            var slots = await _db.Set<ParkingSlot>().AsNoTracking()
                .Select(s => new { s.Id, s.SlotCode, s.Gate, s.Status })
                .ToDictionaryAsync(s => s.Id, ct);

            string ReaderLabel(Guid id) => devices.TryGetValue(id, out var d)
                ? $"{d.Name} (Gate {d.Gate})"
                : "A reader no longer on this server";

            string? ReaderProblem(Guid id) => devices.TryGetValue(id, out var d)
                ? d.IsRevoked ? "The reader it logs as has been revoked." : null
                : "The reader it logs as was deleted.";

            var now = DateTime.UtcNow;
            var rows = new List<DeviceHealth>();

            // ── The cloud ──
            var cloudHost = Uri.TryCreate(_options.CloudBaseUrl, UriKind.Absolute, out var cloud) ? cloud.Host : null;
            var cloudSeen = new[] { sync.LastSnapshotAt, sync.LastPushAt }.Max();
            rows.Add(new DeviceHealth(
                "cloud", "Cloud sync", "cloud", cloudHost, true, sync.CloudConnected, cloudSeen,
                sync.CloudConnected ? null : sync.LastSnapshotError ?? sync.LastPushError, null,
                Detail: sync.LastPushError is null ? null : $"Last send failed: {sync.LastPushError}"));

            // ── Hubs, and the boards behind them ──
            foreach (var hub in hubs.States())
            {
                var hubId = $"hub:{hub.Port}";
                var hubUp = hub.Connected && hub.Responding;
                var online = hub.Nodes.Count(n => n.Node.Online);

                rows.Add(new DeviceHealth(
                    hubId, "ESP-NOW hub", "hub", hub.Simulated ? $"{hub.Port} (simulated)" : hub.Port,
                    true, hubUp, hub.Connected ? hub.LastSeenAt ?? now : hub.LastSeenAt,
                    hub.Error ?? (hub.Connected && !hub.Responding ? "Not answering STATUS." : null), null,
                    Detail: hub.Connected ? $"{online} of {hub.Nodes.Count} boards online" : null));

                foreach (var (node, boundTo) in hub.Nodes.Select(n => (n.Node, n.BoundTo)))
                {
                    var recentError = node.LastErrorAt is DateTime at && now - at <= RecentError;
                    var nodeError = node.LastError switch
                    {
                        "NOT_DELIVERED" => "The last answer or open command didn't reach it.",
                        { } other => other,
                        null => null
                    };

                    if (node.Kind == HubNodeKind.Gate)
                    {
                        rows.Add(new DeviceHealth(
                            $"node:{hub.Port}:{node.Node}", $"Wireless gate {node.Node}", "gateNode",
                            boundTo is Guid d ? ReaderLabel(d) : null, boundTo is not null,
                            hubUp && node.Online, node.LastSeenAt,
                            (boundTo is Guid r ? ReaderProblem(r) : null) ?? (recentError ? nodeError : null),
                            recentError ? node.LastErrorAt : null,
                            DependsOn: hubId,
                            Detail: node.LastTapAt is null ? null : "Card taps reach the server."));
                    }
                    else if (node.Kind == HubNodeKind.Sensor)
                    {
                        var slot = boundTo is Guid s && slots.TryGetValue(s, out var found) ? found : null;
                        var detail = slot?.Status == ParkingSlotStatus.OutOfService
                            ? "Slot is out of service; readings are ignored."
                            : node.Occupied switch
                            {
                                true => $"Sees a vehicle at {node.DistanceCm} cm",
                                false => "Sees an empty slot",
                                null => "No reading yet"
                            };

                        rows.Add(new DeviceHealth(
                            $"node:{hub.Port}:{node.Node}", $"Slot sensor {node.Node}", "slotSensor",
                            boundTo is null ? null
                                : slot is null ? "A slot no longer on this server"
                                : $"Slot {slot.SlotCode} (Gate {slot.Gate})",
                            boundTo is not null, hubUp && node.Online, node.LastSeenAt,
                            recentError ? nodeError : null, recentError ? node.LastErrorAt : null,
                            DependsOn: hubId, Detail: detail,
                            Occupied: node.Occupied, DistanceCm: node.DistanceCm));
                    }
                }
            }

            // ── USB gate readers ──
            foreach (var reader in readers.States())
            {
                rows.Add(new DeviceHealth(
                    $"reader:{reader.Port}",
                    devices.TryGetValue(reader.DeviceId, out var d) ? d.Name : "Gate reader",
                    "gateReader", $"{reader.Port} · {ReaderLabel(reader.DeviceId)}", true,
                    reader.Connected, reader.LastSeenAt,
                    ReaderProblem(reader.DeviceId)
                        ?? (reader.LooksLikeHub ? "This is an ESP-NOW hub. Link the port as a hub." : reader.Error),
                    null));
            }

            // ── Each gate's camera ──
            foreach (var camera in devices.Values
                         .Where(d => d.DeviceType == GateDeviceType.AlprCamera && d.Gate >= 1 && !d.IsRevoked)
                         .OrderBy(d => d.Gate).ThenBy(d => d.Name))
            {
                var live = cameras.Latest(camera.Gate) is not null;
                rows.Add(new DeviceHealth(
                    $"camera:{camera.Id}", camera.Name, "camera", $"Gate {camera.Gate}", true, live,
                    cameras.LastFrameAt(camera.Gate) ?? camera.LastSeenAt,
                    live ? null : "No picture in the last few seconds.", null));
            }

            return Ok(new { checkedAt = now, devices = rows });
        }
    }
}
