using System.IO.Ports;
using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>A COM port linked to the reader it stands for.</summary>
    public record GateReaderBinding(string Port, Guid DeviceId);

    /// <summary>One tap, or one manual open, for the Gate Readers screen.</summary>
    public record GateReaderTap(
        DateTime At, string Port, string? Reader, string? RfidTagId,
        string Direction, bool Opened, string Message);

    public record GateReaderState(
        string Port, Guid DeviceId, bool Connected, string? Error, DateTime? LastTapAt);

    /// <summary>
    /// The barrier readers plugged into this PC by USB
    /// (firmware/aimpark_gate_reader). Holds each port open, hands every
    /// "UID:" line to <see cref="GateTapHandler"/>, and writes the answer back
    /// so the board opens its servo or shakes it.
    /// </summary>
    /// <remarks>
    /// A reader on a cable to the server needs no key: the cable is the proof
    /// it belongs here. Which reader a port stands for — and so which gate — is
    /// chosen by Security on the Gate Readers screen, and kept in a small file
    /// under ProgramData so it survives a reinstall of the service.
    ///
    /// Each port reconnects on its own. Pulling the cable out and putting it
    /// back, or the board rebooting, needs nobody to touch the panel.
    /// </remarks>
    public class UsbGateReaders : BackgroundService
    {
        private const int BaudRate = 115200;
        private const int KeptTaps = 50;
        private static readonly TimeSpan RetryDelay = TimeSpan.FromSeconds(3);

        private static readonly string BindingsPath = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.CommonApplicationData),
            "AimPark", "gate-readers.json");

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<UsbGateReaders> _logger;

        private readonly object _lock = new();
        private readonly Dictionary<string, Session> _sessions = new(StringComparer.OrdinalIgnoreCase);
        private readonly LinkedList<GateReaderTap> _taps = new();
        private CancellationToken _stopping;

        public UsbGateReaders(IServiceScopeFactory scopes, ILogger<UsbGateReaders> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            _stopping = stoppingToken;

            foreach (var binding in LoadBindings())
                Start(binding);

            try
            {
                await Task.Delay(Timeout.Infinite, stoppingToken);
            }
            catch (OperationCanceledException)
            {
                // Shutting down.
            }

            List<Session> sessions;
            lock (_lock) sessions = [.. _sessions.Values];
            foreach (var session in sessions)
                session.Stop();
        }

        // ── What the panel reads ──────────────────────────────────────────────

        public IReadOnlyList<GateReaderState> States()
        {
            lock (_lock)
                return _sessions.Values
                    .OrderBy(s => s.Binding.Port)
                    .Select(s => new GateReaderState(
                        s.Binding.Port, s.Binding.DeviceId, s.Connected, s.Error, s.LastTapAt))
                    .ToList();
        }

        public IReadOnlyList<GateReaderTap> RecentTaps()
        {
            lock (_lock) return [.. _taps];
        }

        // ── What the panel changes ────────────────────────────────────────────

        /// <summary>Links a port to a reader, replacing whatever it was linked to.</summary>
        public void Bind(string port, Guid deviceId)
        {
            Session? old;
            Session? elsewhere;
            lock (_lock)
            {
                _sessions.Remove(port, out old);

                // One reader, one port: two boards logging as the same reader
                // would have their taps land on each other's gate.
                elsewhere = _sessions.Values.FirstOrDefault(s => s.Binding.DeviceId == deviceId);
                if (elsewhere is not null)
                    _sessions.Remove(elsewhere.Binding.Port);
            }

            old?.Stop();
            elsewhere?.Stop();
            Start(new GateReaderBinding(port, deviceId));
            SaveBindings();
        }

        public bool Unbind(string port)
        {
            Session? old;
            lock (_lock) _sessions.Remove(port, out old);
            if (old is null) return false;

            old.Stop();
            SaveBindings();
            return true;
        }

        /// <summary>
        /// The guard's override: opens the barrier without a card. Returns
        /// false when that reader isn't connected.
        /// </summary>
        public bool OpenManually(string port, string openedBy)
        {
            Session? session;
            lock (_lock) _sessions.TryGetValue(port, out session);

            if (session is null || !session.TrySend("CMD:OPEN"))
                return false;

            _logger.LogInformation("Gate on {Port} opened by hand by {User}", port, openedBy);
            Record(new GateReaderTap(DateTime.UtcNow, port, null, null, "-", true, $"Opened by hand by {openedBy}."));
            return true;
        }

        /// <summary>Serial ports on this PC, with Windows' name for each when it has one.</summary>
        public static IReadOnlyList<(string Port, string? Description)> AvailablePorts()
        {
            var names = SerialPort.GetPortNames().Distinct(StringComparer.OrdinalIgnoreCase);
            var descriptions = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

            // "USB-SERIAL CH340 (COM4)" is how a person tells the reader apart
            // from COM1, which every PC has and nothing is plugged into.
            if (OperatingSystem.IsWindows())
            {
                try
                {
                    using var search = new System.Management.ManagementObjectSearcher(
                        "SELECT Name FROM Win32_PnPEntity WHERE Name LIKE '%(COM%'");
                    foreach (var item in search.Get())
                    {
                        var name = item["Name"]?.ToString();
                        if (name is null) continue;

                        var open = name.LastIndexOf("(COM", StringComparison.Ordinal);
                        var port = name[(open + 1)..].TrimEnd(')');
                        descriptions[port] = name[..open].Trim();
                    }
                }
                catch (Exception)
                {
                    // Names are a nicety. The port list stands without them.
                }
            }

            return names
                .OrderBy(n => n.Length).ThenBy(n => n, StringComparer.OrdinalIgnoreCase)
                .Select(n => (n, descriptions.TryGetValue(n, out var d) ? d : null))
                .ToList();
        }

        // ── Connections ───────────────────────────────────────────────────────

        private void Start(GateReaderBinding binding)
        {
            var session = new Session(binding, CancellationTokenSource.CreateLinkedTokenSource(_stopping));
            lock (_lock) _sessions[binding.Port] = session;
            session.Task = Task.Run(() => RunAsync(session));
        }

        private async Task RunAsync(Session session)
        {
            var ct = session.Cancellation.Token;
            var port = session.Binding.Port;

            while (!ct.IsCancellationRequested)
            {
                try
                {
                    using var serial = new SerialPort(port, BaudRate)
                    {
                        NewLine = "\n",
                        ReadTimeout = 500,
                        WriteTimeout = 2000
                    };
                    serial.Open();
                    session.Attach(serial);
                    _logger.LogInformation("Gate reader connected on {Port}", port);

                    // Some boards reset when the port opens. Let it finish
                    // booting so its banner isn't read as a tap.
                    await Task.Delay(1500, ct);
                    serial.DiscardInBuffer();

                    while (!ct.IsCancellationRequested)
                    {
                        string line;
                        try
                        {
                            line = serial.ReadLine().Trim();
                        }
                        catch (TimeoutException)
                        {
                            continue;
                        }

                        if (!line.StartsWith("UID:", StringComparison.Ordinal))
                            continue;

                        var outcome = await HandleTapAsync(session, line[4..].Trim(), ct);
                        session.TrySend(outcome.Opened ? "RESULT:OPEN" : "RESULT:SHUT");
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
                        _logger.LogWarning("Gate reader on {Port}: {Error}", port, ex.Message);
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

        private async Task<GateTapOutcome> HandleTapAsync(Session session, string tag, CancellationToken ct)
        {
            GateTapOutcome outcome;
            string? readerName = null;

            try
            {
                using var scope = _scopes.CreateScope();
                var handler = scope.ServiceProvider.GetRequiredService<GateTapHandler>();
                outcome = await handler.HandleAsync(session.Binding.DeviceId, tag, ct);

                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                readerName = await db.Set<GateDevice>().AsNoTracking()
                    .Where(d => d.Id == session.Binding.DeviceId)
                    .Select(d => d.Name)
                    .FirstOrDefaultAsync(ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                // A barrier that stays shut is the safe failure. The guard can
                // still open it by hand.
                _logger.LogError(ex, "Gate tap on {Port} failed", session.Binding.Port);
                outcome = new GateTapOutcome(false, "-", "Server error. Use Gate Check or open by hand.");
            }

            session.LastTapAt = DateTime.UtcNow;
            Record(new GateReaderTap(DateTime.UtcNow, session.Binding.Port, readerName, tag,
                outcome.Direction, outcome.Opened, outcome.Message));
            return outcome;
        }

        private void Record(GateReaderTap tap)
        {
            lock (_lock)
            {
                _taps.AddFirst(tap);
                while (_taps.Count > KeptTaps) _taps.RemoveLast();
            }
        }

        // ── The bindings file ─────────────────────────────────────────────────

        private List<GateReaderBinding> LoadBindings()
        {
            try
            {
                if (!File.Exists(BindingsPath)) return [];
                return JsonSerializer.Deserialize<List<GateReaderBinding>>(File.ReadAllText(BindingsPath)) ?? [];
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Could not read {Path}: {Error}. Link the readers again in Gate Readers.",
                    BindingsPath, ex.Message);
                return [];
            }
        }

        private void SaveBindings()
        {
            List<GateReaderBinding> bindings;
            lock (_lock) bindings = _sessions.Values.Select(s => s.Binding).ToList();

            Directory.CreateDirectory(Path.GetDirectoryName(BindingsPath)!);
            File.WriteAllText(BindingsPath, JsonSerializer.Serialize(bindings,
                new JsonSerializerOptions { WriteIndented = true }));
        }

        /// <summary>
        /// Checks that a device may be linked to a port: an RFID reader, on a
        /// real gate, not revoked. Returns why not, or null.
        /// </summary>
        public async Task<string?> CheckLinkableAsync(Guid deviceId, CancellationToken ct)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var device = await db.Set<GateDevice>().AsNoTracking().FirstOrDefaultAsync(d => d.Id == deviceId, ct);

            return device switch
            {
                null => "That reader isn't on this server yet. Wait a few seconds and try again.",
                { IsRevoked: true } => "That reader has been revoked.",
                { DeviceType: not GateDeviceType.RfidReader } => "Only an RFID reader can be linked to a port.",
                { Gate: < 1 } => "That reader is for the enrollment desk, not a gate.",
                _ => null
            };
        }

        private sealed class Session
        {
            private readonly object _write = new();
            private SerialPort? _serial;

            public Session(GateReaderBinding binding, CancellationTokenSource cancellation)
            {
                Binding = binding;
                Cancellation = cancellation;
            }

            public GateReaderBinding Binding { get; }
            public CancellationTokenSource Cancellation { get; }
            public Task? Task { get; set; }
            public bool Connected => _serial is not null;
            public string? Error { get; private set; }
            public DateTime? LastTapAt { get; set; }

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

            public bool TrySend(string line)
            {
                lock (_write)
                {
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
