using System.IO.Ports;
using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// A COM port with an ESP-NOW hub on it, and what each board behind the
    /// hub stands for: a gate node for a gate reader, a sensor for a slot.
    /// </summary>
    public record HubBinding(string Port, Dictionary<string, Guid> Gates, Dictionary<string, Guid> Slots);

    /// <param name="BoundTo">The gate reader a gate node logs as, or the slot a sensor watches.</param>
    public record HubNodeState(HubNodeView Node, Guid? BoundTo);

    /// <param name="Responding">Connected, and has answered within <see cref="HubConversation.QuietAfter"/>.</param>
    /// <param name="Simulated">Fed by hand from the Gate Readers screen in a development build.</param>
    /// <param name="Requests">Boards asking to join, by id (MAC), waiting to be accepted and named.</param>
    /// <param name="BoardIds">The id of each paired board, by the name the hub calls it.</param>
    public record HubState(
        string Port, bool Connected, bool Responding, string? Error, DateTime? LastSeenAt,
        bool Simulated, IReadOnlyList<HubNodeState> Nodes,
        IReadOnlyList<(string Id, HubNodeKind Kind)> Requests,
        IReadOnlyDictionary<string, string> BoardIds);

    /// <summary>
    /// The ESP-NOW hubs plugged into this PC (firmware/aimpark_espnow_hub):
    /// one USB cable, and behind it the wireless gates G1, G2 and the slot
    /// sensors S1, S2.
    /// </summary>
    /// <remarks>
    /// A gate node does the same job as a USB gate reader, so its taps go
    /// through <see cref="UsbGateReaders.AnswerTapAsync"/> — the same decision,
    /// the same Recent taps, the same live log against its gate's camera. What
    /// the node stands for is chosen on the Gate Readers screen and kept in
    /// espnow-hubs.json next to gate-readers.json.
    ///
    /// Changing what a node stands for doesn't reopen the port. Reopening it
    /// reboots the hub on Windows, and every node with it.
    ///
    /// Nobody has to link the hub: while none is linked, the free COM ports
    /// are asked PING every few seconds and the one that answers HUB is
    /// linked by itself. Boards join by pairing (<see cref="PairAsync"/>):
    /// accepted and named G1, S2 … on the Gate Readers screen. A gate node
    /// with no reader chosen stands for the gate in its name — G2 is gate 2 —
    /// so nothing needs registering in Gate Devices.
    /// </remarks>
    public class EspNowHubs : BackgroundService
    {
        private const int BaudRate = 115200;
        private const int KeptSimulatedLines = 30;
        private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(3);
        private static readonly TimeSpan LookForHubEvery = TimeSpan.FromSeconds(5);

        /// <summary>A linked hub missing this long is looked for on the other ports.</summary>
        private static readonly TimeSpan MovedAfter = TimeSpan.FromSeconds(15);

        private static readonly string BindingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AimPark", "espnow-hubs.json");

        private readonly IServiceScopeFactory _scopes;
        private readonly UsbGateReaders _readers;
        private readonly ILogger<EspNowHubs> _logger;

        private readonly object _lock = new();
        private readonly Dictionary<string, HubBinding> _bindings = new(StringComparer.OrdinalIgnoreCase);
        private readonly Dictionary<string, HubSession> _sessions = new(StringComparer.OrdinalIgnoreCase);
        private CancellationToken _stopping;

        public EspNowHubs(IServiceScopeFactory scopes, UsbGateReaders readers, ILogger<EspNowHubs> logger)
        {
            _scopes = scopes;
            _readers = readers;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _stopping = stoppingToken;

            foreach (var binding in LoadBindings())
            {
                lock (_lock) _bindings[binding.Port] = binding;
                Start(binding.Port);
            }

            try
            {
                var lostSince = (DateTime?)null;
                while (!stoppingToken.IsCancellationRequested)
                {
                    // Look when no hub is linked, or the linked one has been gone
                    // a while — plugged into another USB socket, so another COM port.
                    List<string> linked;
                    bool anyUp;
                    lock (_lock)
                    {
                        linked = [.. _bindings.Keys];
                        anyUp = _sessions.Values.Any(s => s.Connected);
                    }
                    lostSince = anyUp || linked.Count == 0 ? null : lostSince ?? DateTime.UtcNow;
                    var look = linked.Count == 0 || DateTime.UtcNow - lostSince > MovedAfter;

                    if (look && await FindHubAsync(linked, stoppingToken) is { } found)
                    {
                        _logger.LogInformation("Found the ESP-NOW hub on {Port}", found);
                        if (linked.Count == 0) Bind(found);
                        else Move(linked[0], found);
                        lostSince = null;
                    }
                    await Task.Delay(LookForHubEvery, stoppingToken);
                }
            }
            catch (OperationCanceledException)
            {
                // Shutting down.
            }

            List<HubSession> sessions;
            lock (_lock) sessions = [.. _sessions.Values];
            foreach (var session in sessions)
                session.Stop();
        }

        // ── What the panel reads ──────────────────────────────────────────────

        public IReadOnlyList<HubState> States()
        {
            List<(HubBinding Binding, HubSession Session)> hubs;
            lock (_lock)
                hubs = _bindings.Values
                    .Where(b => _sessions.ContainsKey(b.Port))
                    .OrderBy(b => b.Port)
                    .Select(b => (Copy(b), _sessions[b.Port]))
                    .ToList();

            return hubs.Select(h =>
            {
                var conversation = h.Session.Conversation;
                var lastLine = conversation.LastLineAt;
                var responding = h.Session.Simulated || (h.Session.Connected && !conversation.IsQuiet());

                var nodes = conversation.Nodes()
                    .Select(n => new HubNodeState(n, BoundTo(h.Binding, n)))
                    .ToList();

                var ids = nodes
                    .Select(n => n.Node.Node)
                    .Where(n => HubProtocol.KindOf(n) is HubNodeKind.Gate or HubNodeKind.SensorBoard)
                    .Select(n => (Node: n, Id: conversation.IdOf(n)))
                    .Where(n => n.Id is not null)
                    .ToDictionary(n => n.Node, n => n.Id!);

                return new HubState(h.Binding.Port, h.Session.Connected, responding,
                    conversation.HubError ?? h.Session.Error, lastLine, h.Session.Simulated, nodes,
                    conversation.Requests(), ids);
            }).ToList();
        }

        public bool IsBound(string port)
        {
            lock (_lock) return _bindings.ContainsKey(port);
        }

        // ── What the panel changes ────────────────────────────────────────────

        /// <summary>Links a port as a hub. Keeps what its nodes stood for if it already was one.</summary>
        public void Bind(string port)
        {
            lock (_lock)
            {
                if (_bindings.ContainsKey(port)) return;
                _bindings[port] = new HubBinding(port, [], []);
            }

            Start(port);
            SaveBindings();
        }

        /// <summary>
        /// The hub turned up on another port: links that one instead, keeping
        /// what every board and sensor behind it stands for.
        /// </summary>
        private void Move(string from, string to)
        {
            HubSession? old;
            lock (_lock)
            {
                if (!_bindings.Remove(from, out var binding)) return;
                _sessions.Remove(from, out old);
                _bindings[to] = new HubBinding(to, binding.Gates, binding.Slots);
            }

            old?.Stop();
            Start(to);
            SaveBindings();
        }

        public bool Unbind(string port)
        {
            HubSession? old;
            lock (_lock)
            {
                if (!_bindings.Remove(port)) return false;
                _sessions.Remove(port, out old);
            }

            old?.Stop();
            SaveBindings();
            return true;
        }

        /// <summary>
        /// Accepts a board asking to join and names it: G1–G9 for a gate,
        /// S1–S9 for a sensor board. A name already in use moves to the new
        /// board (a replacement). Returns why not, or null.
        /// </summary>
        public async Task<string?> PairAsync(string port, string id, string node)
        {
            node = node.ToUpperInvariant();
            id = id.ToUpperInvariant();

            HubSession? session;
            lock (_lock) _sessions.TryGetValue(port, out session);
            if (session is null || !session.Connected)
                return $"The hub on {port} isn't connected.";

            return await session.Conversation.PairAsync(id, node);
        }

        /// <summary>
        /// Removes a board from the hub, and forgets what it and its sensors
        /// stood for. Returns why not, or null.
        /// </summary>
        public async Task<string?> ForgetAsync(string port, string node)
        {
            node = node.ToUpperInvariant();

            HubSession? session;
            lock (_lock) _sessions.TryGetValue(port, out session);
            if (session is null || !session.Connected)
                return $"The hub on {port} isn't connected.";

            if (await session.Conversation.ForgetAsync(node) is { } problem)
                return problem;

            lock (_lock)
                if (_bindings.TryGetValue(port, out var binding))
                {
                    binding.Gates.Remove(node);
                    foreach (var sensor in binding.Slots.Keys.Where(s => HubProtocol.BoardOf(s) == node).ToList())
                        binding.Slots.Remove(sensor);
                }
            SaveBindings();
            return null;
        }

        /// <summary>
        /// What a paired gate board's parking logs carry as their recording
        /// device: the same board always gets the same id, without registering.
        /// </summary>
        public static Guid BoardGuid(string boardId)
        {
            var hash = System.Security.Cryptography.MD5.HashData(
                System.Text.Encoding.UTF8.GetBytes("aimpark-gate-board:" + boardId.ToUpperInvariant()));
            return new Guid(hash);
        }

        public static string BoardName(int gate) => $"Gate {gate} board";

        /// <summary>
        /// Says which gate reader a gate node logs as, or with null, none.
        /// Returns why not, or null.
        /// </summary>
        public async Task<string?> MapGateAsync(string port, string node, Guid? deviceId, CancellationToken ct)
        {
            node = node.ToUpperInvariant();
            if (HubProtocol.KindOf(node) != HubNodeKind.Gate)
                return $"{node} isn't a gate node.";
            if (!IsBound(port))
                return $"{port} isn't linked as a hub.";

            if (deviceId is Guid linking)
            {
                if (await _readers.CheckLinkableAsync(linking, ct) is { } problem)
                    return problem;

                // One reader, one place: a cabled reader and a wireless gate
                // logging as the same device would land on each other's gate.
                _readers.ReleaseDevice(linking);
            }

            lock (_lock)
            {
                if (!_bindings.TryGetValue(port, out var binding))
                    return $"{port} isn't linked as a hub.";

                if (deviceId is Guid id)
                {
                    foreach (var other in _bindings.Values)
                        foreach (var taken in other.Gates.Where(g => g.Value == id).Select(g => g.Key).ToList())
                            other.Gates.Remove(taken);
                    binding.Gates[node] = id;
                }
                else
                {
                    binding.Gates.Remove(node);
                }
            }

            SaveBindings();
            return null;
        }

        /// <summary>
        /// Says which slot a sensor watches, or with null, none. Its latest
        /// reading is applied straight away. Returns why not, or null.
        /// </summary>
        public async Task<string?> MapSensorAsync(string port, string node, Guid? slotId, CancellationToken ct)
        {
            node = node.ToUpperInvariant();
            if (HubProtocol.KindOf(node) != HubNodeKind.Sensor)
                return $"{node} isn't a slot sensor.";

            if (slotId is Guid watching)
            {
                using var scope = _scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                if (!await db.Set<ParkingSlot>().AnyAsync(s => s.Id == watching, ct))
                    return "That slot isn't on this server yet. Wait a few seconds and try again.";
            }

            HubSession? session;
            lock (_lock)
            {
                if (!_bindings.TryGetValue(port, out var binding))
                    return $"{port} isn't linked as a hub.";

                if (slotId is Guid id)
                {
                    // One sensor per slot. Two disagreeing about the same bay
                    // would flip it back and forth.
                    foreach (var other in _bindings.Values)
                        foreach (var taken in other.Slots.Where(s => s.Value == id).Select(s => s.Key).ToList())
                            other.Slots.Remove(taken);
                    binding.Slots[node] = id;
                }
                else
                {
                    binding.Slots.Remove(node);
                }

                _sessions.TryGetValue(port, out session);
            }

            SaveBindings();

            var reading = session?.Conversation.Nodes().FirstOrDefault(n => n.Node == node);
            if (slotId is not null && reading is { Online: true, Occupied: bool occupied })
                await ApplySlotAsync(port, node, occupied, ct);

            return null;
        }

        /// <summary>Unlinks this reader from any gate node, so it can be linked to a USB port instead.</summary>
        public void ReleaseDevice(Guid deviceId)
        {
            var changed = false;
            lock (_lock)
                foreach (var binding in _bindings.Values)
                    foreach (var node in binding.Gates.Where(g => g.Value == deviceId).Select(g => g.Key).ToList())
                        changed |= binding.Gates.Remove(node);

            if (changed) SaveBindings();
        }

        /// <summary>
        /// The guard's override for a wireless gate. Returns why not, or null.
        /// "Sent" is not "opened": if the node can't be reached the hub says
        /// ERR:NOT_DELIVERED, which shows on the node's row.
        /// </summary>
        public string? OpenManually(string port, string node, string openedBy)
        {
            node = node.ToUpperInvariant();
            HubSession? session;
            Guid? deviceId = null;
            lock (_lock)
            {
                _sessions.TryGetValue(port, out session);
                if (_bindings.TryGetValue(port, out var binding) && binding.Gates.TryGetValue(node, out var id))
                    deviceId = id;
            }

            if (session is null || !session.Connected)
                return $"The hub on {port} isn't connected.";
            if (deviceId is null && HubProtocol.GateOf(node) is null)
                return $"{node} isn't linked to a gate reader.";
            if (session.Conversation.Nodes().FirstOrDefault(n => n.Node == node) is not { Online: true })
                return $"{node} is offline. Check its power, then open the barrier by hand.";
            if (!session.Conversation.Open(node))
                return $"Could not write to the hub on {port}.";

            if (deviceId is Guid device)
                _readers.RecordManualOpen(port, node, device, openedBy);
            else
                _readers.RecordManualOpen(port, node, HubProtocol.GateOf(node)!.Value, openedBy);
            return null;
        }

        /// <summary>
        /// Development only: feeds one line to a hub as if the board had sent
        /// it, and answers with everything the server has written back. The
        /// hub then counts as connected, so the screens can be tried without
        /// the hardware. Null when the port isn't linked as a hub.
        /// </summary>
        public async Task<IReadOnlyList<string>?> SimulateAsync(string port, string line, CancellationToken ct)
        {
            HubSession? session;
            lock (_lock) _sessions.TryGetValue(port, out session);
            if (session is null) return null;

            if (!session.Simulated)
            {
                session.Simulate();
                session.Conversation.Connected();
                await session.Conversation.Receive("# Ready (simulated)", ct);
            }

            await session.Conversation.Receive(line, ct);
            return session.SimulatedLines();
        }

        // ── Connections ───────────────────────────────────────────────────────

        /// <summary>
        /// Asks each free COM port PING; the one that answers HUB is the hub.
        /// Ports a USB gate reader is linked to are left alone.
        /// </summary>
        private async Task<string?> FindHubAsync(IReadOnlyCollection<string> skip, CancellationToken ct)
        {
            var ports = SerialPort.GetPortNames()
                .Distinct(StringComparer.OrdinalIgnoreCase)
                .Where(p => !_readers.IsBound(p) && !skip.Contains(p, StringComparer.OrdinalIgnoreCase))
                .ToList();

            foreach (var port in ports)
            {
                try
                {
                    using var serial = new SerialPort(port, BaudRate) { NewLine = "\n", ReadTimeout = 300, WriteTimeout = 1000 };
                    serial.Open();
                    // Most boards reset when the port opens: let it finish booting.
                    await Task.Delay(1500, ct);
                    serial.DiscardInBuffer();
                    serial.WriteLine(HubProtocol.Ping);

                    var until = DateTime.UtcNow.AddSeconds(2);
                    while (DateTime.UtcNow < until)
                    {
                        string line;
                        try { line = serial.ReadLine(); }
                        catch (TimeoutException) { continue; }

                        if (HubProtocol.Parse(line) is HubHello)
                            return port;
                    }
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    throw;
                }
                catch (Exception)
                {
                    // Busy in another program, or not something we can open.
                }
            }
            return null;
        }

        private void Start(string port)
        {
            var session = new HubSession(port, CancellationTokenSource.CreateLinkedTokenSource(_stopping));
            session.Conversation = new HubConversation(
                send: session.TrySend,
                answerTap: (node, uid, ct) => AnswerTapAsync(port, node, uid, ct),
                slotSeen: (node, occupied, _, ct) => ApplySlotAsync(port, node, occupied, ct),
                log: message => _logger.LogInformation("Hub on {Port}: {Message}", port, message));

            lock (_lock) _sessions[port] = session;
            session.Task = Task.Run(() => RunAsync(session));
        }

        private async Task RunAsync(HubSession session)
        {
            var ct = session.Cancellation.Token;
            var port = session.Port;

            while (!ct.IsCancellationRequested)
            {
                if (session.Simulated)
                {
                    // Nothing to open: the screen is playing the hub.
                    session.Conversation.Tick();
                    try { await Task.Delay(500, ct); }
                    catch (OperationCanceledException) { break; }
                    continue;
                }

                try
                {
                    using var serial = new SerialPort(port, BaudRate)
                    {
                        NewLine = "\n",
                        ReadTimeout = 250,
                        WriteTimeout = 2000
                    };
                    serial.Open();
                    session.Attach(serial);
                    session.Conversation.Connected();
                    _logger.LogInformation("ESP-NOW hub connected on {Port}", port);

                    while (!ct.IsCancellationRequested)
                    {
                        try
                        {
                            // Not awaited: G1's tap must not hold up G2's, or a slot update.
                            _ = session.Conversation.Receive(serial.ReadLine(), ct);
                        }
                        catch (TimeoutException)
                        {
                            // Quiet is normal: nodes only speak when something changes.
                        }

                        session.Conversation.Tick();

                        // Asked every 10 s and silent for 25: a hung hub. Reopening
                        // the port reboots it, which is the cure.
                        if (session.Conversation.IsQuiet())
                            throw new TimeoutException("The hub stopped answering. Reconnecting, which restarts it.");
                    }
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    // Unplugged, busy in another program, or not there at all.
                    if (session.Error != ex.Message)
                        _logger.LogWarning("ESP-NOW hub on {Port}: {Error}", port, ex.Message);
                    session.Detach(ex.Message);
                }
                finally
                {
                    session.Detach(session.Error);
                }

                try
                {
                    await Task.Delay(RetryDelay, ct);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }

        private async Task<bool> AnswerTapAsync(string port, string node, string uid, CancellationToken ct)
        {
            Guid? deviceId;
            lock (_lock)
                deviceId = _bindings.TryGetValue(port, out var b) && b.Gates.TryGetValue(node, out var id) ? id : null;

            if (deviceId is Guid device)
                return (await _readers.AnswerTapAsync(port, node, device, uid, ct)).Opened;

            // No reader chosen: a paired gate board stands for the gate in its name.
            if (HubProtocol.GateOf(node) is int gate)
            {
                HubSession? session;
                lock (_lock) _sessions.TryGetValue(port, out session);
                var boardId = session?.Conversation.IdOf(node) ?? node;
                return (await _readers.AnswerGateTapAsync(port, node, gate, BoardGuid(boardId), uid, ct)).Opened;
            }

            _readers.Record(new GateReaderTap(DateTime.UtcNow, port, null, uid, "-", false,
                $"{node} isn't a gate.", node));
            return false;
        }

        /// <summary>
        /// A sensor's reading, applied to its slot under <see cref="SlotSensorRule"/>.
        /// Saved through the ordinary context, so the outbox carries it to the
        /// cloud and allocation sees it at once.
        /// </summary>
        private async Task ApplySlotAsync(string port, string node, bool occupied, CancellationToken ct)
        {
            Guid? slotId;
            lock (_lock)
                slotId = _bindings.TryGetValue(port, out var b) && b.Slots.TryGetValue(node, out var id) ? id : null;
            if (slotId is not Guid watched) return;

            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();

            var slot = await db.Set<ParkingSlot>().FirstOrDefaultAsync(s => s.Id == watched, ct);
            if (slot is null) return;

            var held = !occupied && await db.Set<ParkingLog>()
                .AnyAsync(l => l.SlotId == watched && l.ExitTime == null, ct);

            if (SlotSensorRule.Next(slot.Status, occupied, held) is not { } status)
                return;

            slot.Status = status;
            slot.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync(ct);

            _logger.LogInformation("Slot {Slot} is now {Status}, from sensor {Node} on {Port}",
                slot.SlotCode, status, node, port);
        }

        private static Guid? BoundTo(HubBinding binding, HubNodeView node) => node.Kind switch
        {
            HubNodeKind.Gate => binding.Gates.TryGetValue(node.Node, out var d) ? d : null,
            HubNodeKind.Sensor => binding.Slots.TryGetValue(node.Node, out var s) ? s : null,
            _ => null
        };

        private static HubBinding Copy(HubBinding b) => new(b.Port, new(b.Gates), new(b.Slots));

        // ── The bindings file ─────────────────────────────────────────────────

        private List<HubBinding> LoadBindings()
        {
            try
            {
                if (!File.Exists(BindingsPath)) return [];
                var bindings = JsonSerializer.Deserialize<List<HubBinding>>(File.ReadAllText(BindingsPath)) ?? [];

                // Node names are matched as the hub prints them: upper case.
                return bindings.Select(b => new HubBinding(b.Port,
                        (b.Gates ?? []).ToDictionary(g => g.Key.ToUpperInvariant(), g => g.Value),
                        (b.Slots ?? []).ToDictionary(s => s.Key.ToUpperInvariant(), s => s.Value)))
                    .ToList();
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Could not read {Path}: {Error}. Link the hub again in Gate Readers.",
                    BindingsPath, ex.Message);
                return [];
            }
        }

        private void SaveBindings()
        {
            List<HubBinding> bindings;
            lock (_lock) bindings = _bindings.Values.Select(Copy).ToList();

            Directory.CreateDirectory(Path.GetDirectoryName(BindingsPath)!);
            File.WriteAllText(BindingsPath, JsonSerializer.Serialize(bindings,
                new JsonSerializerOptions { WriteIndented = true }));
        }

        private sealed class HubSession
        {
            private readonly object _write = new();
            private readonly LinkedList<string> _simulatedLines = new();
            private SerialPort? _serial;

            public HubSession(string port, CancellationTokenSource cancellation)
            {
                Port = port;
                Cancellation = cancellation;
            }

            public string Port { get; }
            public CancellationTokenSource Cancellation { get; }
            public HubConversation Conversation { get; set; } = null!;
            public Task? Task { get; set; }
            public bool Simulated { get; private set; }
            public bool Connected => Simulated || _serial is not null;
            public string? Error { get; private set; }

            public void Attach(SerialPort serial)
            {
                lock (_write) _serial = serial;
                Error = null;
            }

            public void Detach(string? error)
            {
                lock (_write) _serial = null;
                Error = error;
            }

            public void Simulate()
            {
                Simulated = true;
                Error = null;
            }

            public IReadOnlyList<string> SimulatedLines()
            {
                lock (_write) return [.. _simulatedLines];
            }

            public bool TrySend(string line)
            {
                lock (_write)
                {
                    if (Simulated)
                    {
                        _simulatedLines.AddFirst(line);
                        while (_simulatedLines.Count > KeptSimulatedLines) _simulatedLines.RemoveLast();
                        return true;
                    }

                    if (_serial is null) return false;
                    try
                    {
                        _serial.WriteLine(line);
                        return true;
                    }
                    catch (Exception)
                    {
                        return false;
                    }
                }
            }

            public void Stop()
            {
                Cancellation.Cancel();
                try
                {
                    Task?.Wait(TimeSpan.FromSeconds(3));
                }
                catch (AggregateException)
                {
                    // It was stopping anyway.
                }
            }
        }
    }
}
