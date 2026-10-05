using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Sync.Site.Cameras;
using AimPark.API.Sync.Site.GateReaders;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// Every piece of hardware the guard post depends on, in one list: the
    /// hub and the boards behind it, the USB readers, each gate's camera, and
    /// the link to the cloud.
    /// </summary>
    /// <remarks>
    /// Built in one place for two readers: the guard post's own panel
    /// (<c>GET /api/site/device-health</c>) and the cloud, which gets a copy
    /// every few seconds (<see cref="SiteHealthPusher"/>) so the online panel
    /// shows the same thing instead of "unknown".
    ///
    /// Each row says what the device is, what it stands for, whether it is up,
    /// when it was last heard from, and the last thing that went wrong.
    /// <c>dependsOn</c> names the row a device can't work without — a gate node
    /// behind a hub that has been unplugged is down because of the hub.
    /// </remarks>
    public class DeviceHealthReport
    {
        /// <summary>A node error older than this is history, not a problem.</summary>
        private static readonly TimeSpan RecentError = TimeSpan.FromMinutes(10);

        private readonly UsbGateReaders _readers;
        private readonly EspNowHubs _hubs;
        private readonly CameraFrames _cameras;
        private readonly SiteSyncStatus _sync;
        private readonly SiteOptions _options;
        private readonly AppDbContext _db;

        public DeviceHealthReport(
            UsbGateReaders readers,
            EspNowHubs hubs,
            CameraFrames cameras,
            SiteSyncStatus sync,
            IOptions<SiteOptions> options,
            AppDbContext db)
        {
            _readers = readers;
            _hubs = hubs;
            _cameras = cameras;
            _sync = sync;
            _options = options.Value;
            _db = db;
        }

        public async Task<SiteHealthReport> BuildAsync(CancellationToken ct)
        {
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
            var cloudSeen = new[] { _sync.LastSnapshotAt, _sync.LastPushAt }.Max();
            rows.Add(new DeviceHealth(
                "cloud", "Cloud sync", "cloud", cloudHost, true, _sync.CloudConnected, cloudSeen,
                _sync.CloudConnected ? null : _sync.LastSnapshotError ?? _sync.LastPushError, null,
                Detail: _sync.LastPushError is null ? null : $"Last send failed: {_sync.LastPushError}"));

            // ── Hubs, and the boards behind them ──
            foreach (var hub in _hubs.States())
            {
                var hubId = $"hub:{hub.Port}";
                var hubUp = hub.Connected && hub.Responding;
                // Boards, not the sensors on them: S1's nine slots are one board.
                var boards = hub.Nodes.Where(n => n.Node.Kind != HubNodeKind.Sensor).ToList();
                var online = boards.Count(n => n.Node.Online);

                rows.Add(new DeviceHealth(
                    hubId, "ESP-NOW hub", "hub", hub.Simulated ? $"{hub.Port} (simulated)" : hub.Port,
                    true, hubUp, hub.Connected ? hub.LastSeenAt ?? now : hub.LastSeenAt,
                    hub.Error ?? (hub.Connected && !hub.Responding ? "Not answering STATUS." : null), null,
                    Detail: hub.Connected ? $"{online} of {boards.Count} boards online" : null));

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
                        // With no reader chosen, a gate node stands for the gate in its name.
                        var byName = HubProtocol.GateOf(node.Node) is int gate ? $"Gate {gate}" : null;
                        rows.Add(new DeviceHealth(
                            $"node:{hub.Port}:{node.Node}", $"Wireless gate {node.Node}", "gateNode",
                            boundTo is Guid d ? ReaderLabel(d) : byName, boundTo is not null || byName is not null,
                            hubUp && node.Online, node.LastSeenAt,
                            (boundTo is Guid r ? ReaderProblem(r) : null) ?? (recentError ? nodeError : null),
                            recentError ? node.LastErrorAt : null,
                            DependsOn: hubId,
                            Detail: node.LastTapAt is null ? null : "Card taps reach the server."));
                    }
                    else if (node.Kind == HubNodeKind.SensorBoard)
                    {
                        var sensors = hub.Nodes
                            .Where(n => n.Node.Kind == HubNodeKind.Sensor
                                     && HubProtocol.BoardOf(n.Node.Node) == node.Node)
                            .ToList();
                        var linked = sensors.Count(n => n.BoundTo is not null);

                        rows.Add(new DeviceHealth(
                            $"node:{hub.Port}:{node.Node}", $"Sensor board {node.Node}", "sensorBoard",
                            sensors.Count == 0 ? null : $"{linked} of {sensors.Count} sensors linked to slots",
                            true, hubUp && node.Online, node.LastSeenAt,
                            recentError ? nodeError : null, recentError ? node.LastErrorAt : null,
                            DependsOn: hubId,
                            Detail: sensors.Count == 0 ? "No reading yet"
                                : $"{sensors.Count(n => n.Node.Occupied == true)} of {sensors.Count} slots taken"));
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
                            DependsOn: $"node:{hub.Port}:{HubProtocol.BoardOf(node.Node)}", Detail: detail,
                            Occupied: node.Occupied, DistanceCm: node.DistanceCm));
                    }
                }
            }

            // ── USB gate readers ──
            foreach (var reader in _readers.States())
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
                var live = _cameras.Latest(camera.Gate) is not null;
                rows.Add(new DeviceHealth(
                    $"camera:{camera.Id}", camera.Name, "camera", $"Gate {camera.Gate}", true, live,
                    _cameras.LastFrameAt(camera.Gate) ?? camera.LastSeenAt,
                    live ? null : "No picture in the last few seconds.", null));
            }

            return new SiteHealthReport { CheckedAt = now, Devices = rows };
        }
    }
}
