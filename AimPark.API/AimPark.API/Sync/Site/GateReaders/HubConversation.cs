namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>What the server knows about one board behind the hub, right now.</summary>
    public record HubNodeView(
        string Node,
        HubNodeKind? Kind,
        bool Online,
        DateTime? LastSeenAt,
        DateTime? WentOfflineAt,
        string? LastError,
        DateTime? LastErrorAt,
        DateTime? LastTapAt,
        bool? Occupied,
        int? DistanceCm,
        DateTime? SlotChangedAt);

    /// <summary>
    /// The server's half of one conversation with an ESP-NOW hub: reads its
    /// lines, keeps track of every node, and writes the answers back.
    /// </summary>
    /// <remarks>
    /// Knows nothing about ports or the database. What a tap or a slot reading
    /// means is handed to the delegates, and every reply goes out through
    /// <c>send</c> — which is how the tests stand in for the hub.
    ///
    /// Each node's work runs in order, but nodes don't wait on each other: a
    /// slow lookup for a card at G1 must not keep G2's barrier shut.
    ///
    /// Opening the hub's port on Windows reboots it, and for the first few
    /// seconds after it says Ready it reports every node OFFLINE simply
    /// because it hasn't heard a heartbeat yet. Those are ignored, so a
    /// reconnect doesn't page the guard about four boards that never left.
    /// </remarks>
    public sealed class HubConversation
    {
        /// <summary>How often the hub is asked for every node's state.</summary>
        public static readonly TimeSpan StatusEvery = TimeSpan.FromSeconds(10);

        /// <summary>After Ready, how long an OFFLINE only means "not heard yet". Nodes heartbeat every 5 s.</summary>
        public static readonly TimeSpan SettleFor = TimeSpan.FromSeconds(8);

        /// <summary>A hub that hasn't printed its banner by now didn't reboot when the port opened.</summary>
        public static readonly TimeSpan ReadyWithin = TimeSpan.FromSeconds(4);

        /// <summary>With STATUS every 10 s, a hub this quiet has stopped answering.</summary>
        public static readonly TimeSpan QuietAfter = TimeSpan.FromSeconds(25);

        /// <summary>
        /// The boards the firmware is built for. Listed before the hub has said
        /// a word. A sensor board's sensors (S1/1, S1/2 …) appear once it reports.
        /// </summary>
        public static readonly string[] ExpectedNodes = ["G1", "G2", "S1", "S2"];

        private readonly Func<string, bool> _send;
        private readonly Func<string, string, CancellationToken, Task<bool>> _answerTap;
        private readonly Func<string, bool, int, CancellationToken, Task> _slotSeen;
        private readonly Func<DateTime> _now;
        private readonly Action<string>? _log;

        /// <summary>A board's join request shows this long after it last asked. It asks every 2 s.</summary>
        public static readonly TimeSpan RequestShownFor = TimeSpan.FromSeconds(15);

        /// <summary>How long a PAIR or FORGET waits for the hub's answer.</summary>
        public static readonly TimeSpan CommandTimeout = TimeSpan.FromSeconds(6);

        private readonly object _lock = new();
        private readonly Dictionary<string, Node> _nodes = new(StringComparer.Ordinal);
        private readonly Dictionary<string, Task> _queues = new(StringComparer.Ordinal);

        // Pairing: boards asking to join, by id; what each paired board's id is,
        // by name; and the PAIR / FORGET waiting for the hub's answer.
        private readonly Dictionary<string, (HubNodeKind Kind, DateTime LastAt)> _requests = new(StringComparer.Ordinal);
        private readonly Dictionary<string, string> _boardIds = new(StringComparer.Ordinal);
        private readonly Dictionary<string, TaskCompletionSource<string?>> _waiting = new(StringComparer.Ordinal);

        private bool _ready;
        private DateTime _readyBy;
        private DateTime _settleUntil;
        private DateTime _nextStatus;
        private DateTime _connectedAt;

        /// <param name="send">Writes one line to the hub. False when it couldn't.</param>
        /// <param name="answerTap">A card at a gate node: true to open.</param>
        /// <param name="slotSeen">A sensor's reading: occupied or not, and the distance in cm.</param>
        public HubConversation(
            Func<string, bool> send,
            Func<string, string, CancellationToken, Task<bool>> answerTap,
            Func<string, bool, int, CancellationToken, Task> slotSeen,
            Func<DateTime>? now = null,
            Action<string>? log = null)
        {
            _send = send;
            _answerTap = answerTap;
            _slotSeen = slotSeen;
            _now = now ?? (() => DateTime.UtcNow);
            _log = log;

            foreach (var name in ExpectedNodes)
                _nodes[name] = new Node(name);
        }

        /// <summary>The hub has said Ready, or was given long enough to.</summary>
        public bool Ready
        {
            get { lock (_lock) return _ready; }
        }

        public DateTime? LastLineAt { get; private set; }

        /// <summary>The hub's own complaint, e.g. "This board is not the hub". Cleared when it boots again.</summary>
        public string? HubError { get; private set; }

        // ── The port ──────────────────────────────────────────────────────────

        /// <summary>The port just opened. Expect a reboot.</summary>
        public void Connected()
        {
            lock (_lock)
            {
                _connectedAt = _now();
                _ready = false;
                _readyBy = _connectedAt + ReadyWithin;
                HubError = null;
            }
        }

        /// <summary>
        /// Ready, asked for STATUS, and silent since: the hub has hung, or the
        /// board on this port isn't a hub at all.
        /// </summary>
        public bool IsQuiet()
        {
            lock (_lock)
            {
                if (!_ready) return false;
                var heard = LastLineAt is DateTime last && last > _connectedAt ? last : _connectedAt;
                return _now() - heard > QuietAfter;
            }
        }

        /// <summary>
        /// Call a few times a second. Sends STATUS when it is due, and stops
        /// waiting for a banner that isn't coming.
        /// </summary>
        public void Tick()
        {
            var now = _now();
            bool poll;
            lock (_lock)
            {
                if (!_ready && now >= _readyBy)
                {
                    // No reboot on open (not every board resets): it was
                    // already running, so its OFFLINEs are real.
                    _ready = true;
                    _settleUntil = now;
                    _nextStatus = now;
                }

                poll = _ready && now >= _nextStatus;
                if (poll) _nextStatus = now + StatusEvery;
            }

            if (poll) _send(HubProtocol.StatusRequest);
        }

        /// <summary>
        /// One line from the hub. Returns at once: the work it starts — a tap
        /// to answer, a slot to save — is the returned task, which the port
        /// loop does not wait for and the tests do.
        /// </summary>
        public Task Receive(string raw, CancellationToken ct = default)
        {
            var line = raw.Trim();
            if (line.Length == 0) return Task.CompletedTask;

            var now = _now();
            LastLineAt = now;

            if (HubProtocol.IsBanner(line))
            {
                lock (_lock)
                {
                    _ready = false;
                    _readyBy = now + ReadyWithin;
                    HubError = null;
                }
                return Task.CompletedTask;
            }

            if (HubProtocol.IsReady(line))
            {
                lock (_lock)
                {
                    _ready = true;
                    _settleUntil = now + SettleFor;
                    _nextStatus = now;
                }
                Tick();
                return Task.CompletedTask;
            }

            switch (HubProtocol.Parse(line))
            {
                case HubTap tap:
                    lock (_lock)
                    {
                        var node = NodeFor(tap.Node);
                        node.Online = true;
                        node.LastSeenAt = now;
                        node.LastTapAt = now;
                    }
                    return InOrder(tap.Node, ct, async token =>
                    {
                        bool opened;
                        try
                        {
                            opened = await _answerTap(tap.Node, tap.Uid, token);
                        }
                        catch (Exception ex) when (ex is not OperationCanceledException)
                        {
                            // Shut is the safe answer. The guard can still open by hand.
                            _log?.Invoke($"Tap at {tap.Node} failed: {ex.Message}");
                            opened = false;
                        }
                        _send(HubProtocol.Result(tap.Node, opened));
                    });

                case HubSlot slot:
                    lock (_lock)
                    {
                        // A reading is the board checking in, too.
                        var board = NodeFor(HubProtocol.BoardOf(slot.Node));
                        board.Online = true;
                        board.LastSeenAt = now;

                        var node = NodeFor(slot.Node);
                        node.Online = true;
                        node.LastSeenAt = now;
                        if (node.Occupied != slot.Occupied) node.SlotChangedAt = now;
                        node.Occupied = slot.Occupied;
                        node.DistanceCm = slot.DistanceCm;
                    }
                    // Every reading goes through, STATUS repeats included: the
                    // slot may have been changed under the sensor since (a car
                    // logged out at the gate while the bay is still taken).
                    return InOrder(slot.Node, ct, token => _slotSeen(slot.Node, slot.Occupied, slot.DistanceCm, token));

                case HubPresence presence:
                    lock (_lock)
                    {
                        // A sensor board comes and goes with all its sensors.
                        // Coming back, they each report in their own lines.
                        List<Node> affected = presence.Online
                            ? [NodeFor(presence.Node)]
                            : _nodes.Values
                                .Where(n => n.Name == presence.Node
                                         || HubProtocol.BoardOf(n.Name) == presence.Node)
                                .ToList();

                        foreach (var node in affected)
                        {
                            if (presence.Online)
                            {
                                node.Online = true;
                                node.LastSeenAt = now;
                            }
                            else if (now >= _settleUntil)
                            {
                                if (node.Online) node.WentOfflineAt = now;
                                node.Online = false;
                            }
                        }
                    }
                    return Task.CompletedTask;

                case HubNodeError error:
                    lock (_lock)
                    {
                        var node = NodeFor(error.Node);
                        node.LastError = error.Code;
                        node.LastErrorAt = now;
                    }
                    _log?.Invoke($"{error.Node}: {error.Code}");
                    return Task.CompletedTask;

                case HubPairRequest request:
                    lock (_lock) _requests[request.Id] = (request.Kind, now);
                    return Task.CompletedTask;

                case HubPaired paired:
                    lock (_lock)
                    {
                        // A name moving to a new board (a replacement) or a board
                        // under a new name: the id is what changed hands.
                        foreach (var stale in _boardIds.Where(b => b.Value == paired.Id && b.Key != paired.Node)
                                     .Select(b => b.Key).ToList())
                            _boardIds.Remove(stale);
                        _boardIds[paired.Node] = paired.Id;
                        _requests.Remove(paired.Id);
                        NodeFor(paired.Node);
                    }
                    Answer(paired.Id, null);
                    Answer(paired.Node, null);
                    return Task.CompletedTask;

                case HubForgot forgot:
                    lock (_lock)
                    {
                        _boardIds.Remove(forgot.Node);
                        // Its sensors go with it, and it isn't expected any more
                        // unless it is one of the boards the lot is built with.
                        foreach (var name in _nodes.Keys
                                     .Where(n => n == forgot.Node || HubProtocol.BoardOf(n) == forgot.Node).ToList())
                        {
                            if (ExpectedNodes.Contains(name))
                            {
                                _nodes[name] = new Node(name);
                            }
                            else
                            {
                                _nodes.Remove(name);
                            }
                        }
                    }
                    Answer(forgot.Node, null);
                    return Task.CompletedTask;

                case HubCommandError error:
                    Answer(error.Id, error.Message);
                    _log?.Invoke($"{error.Id}: {error.Message}");
                    return Task.CompletedTask;

                case HubHello:
                    return Task.CompletedTask;

                case HubComment comment:
                    // The hub's own failures arrive as comments: flashed with the
                    // wrong sketch, or ESP-NOW not starting.
                    if (comment.Text.Contains("is not the hub", StringComparison.OrdinalIgnoreCase)
                        || comment.Text.Contains("failed", StringComparison.OrdinalIgnoreCase))
                        HubError = comment.Text;
                    return Task.CompletedTask;

                default:
                    _log?.Invoke($"Unrecognised line from the hub: {line}");
                    return Task.CompletedTask;
            }
        }

        /// <summary>Sends the guard's open to a gate node. False when the line couldn't be written.</summary>
        public bool Open(string node) => _send(HubProtocol.Open(node));

        // ── Pairing ───────────────────────────────────────────────────────────

        /// <summary>Boards asking to join right now: id and what kind of board.</summary>
        public IReadOnlyList<(string Id, HubNodeKind Kind)> Requests()
        {
            var cutoff = _now() - RequestShownFor;
            lock (_lock)
                return _requests
                    .Where(r => r.Value.LastAt >= cutoff)
                    .OrderBy(r => r.Key, StringComparer.Ordinal)
                    .Select(r => (r.Key, r.Value.Kind))
                    .ToList();
        }

        /// <summary>The id (MAC) of the board the hub calls this name, once it has said.</summary>
        public string? IdOf(string node)
        {
            lock (_lock) return _boardIds.TryGetValue(node, out var id) ? id : null;
        }

        /// <summary>
        /// Accepts a board asking to join and has the hub call it
        /// <paramref name="node"/>. Returns why not, or null.
        /// </summary>
        public Task<string?> PairAsync(string id, string node)
        {
            HubNodeKind kind;
            lock (_lock)
            {
                if (!_requests.TryGetValue(id, out var request))
                    return Task.FromResult<string?>("That board isn't asking to join any more. Power it on and wait a few seconds.");
                kind = request.Kind;
            }

            if (!HubProtocol.FitsName(node, kind))
                return Task.FromResult<string?>(kind == HubNodeKind.Gate
                    ? "A gate board is named G1 to G9."
                    : "A sensor board is named S1 to S9.");

            return CommandAsync(id, HubProtocol.Pair(id, node));
        }

        /// <summary>Removes a board from the hub. Returns why not, or null.</summary>
        public Task<string?> ForgetAsync(string node) => CommandAsync(node, HubProtocol.Forget(node));

        private async Task<string?> CommandAsync(string key, string line)
        {
            var waiter = new TaskCompletionSource<string?>(TaskCreationOptions.RunContinuationsAsynchronously);
            lock (_lock) _waiting[key] = waiter;
            try
            {
                if (!_send(line))
                    return "The hub isn't connected.";

                var done = await Task.WhenAny(waiter.Task, Task.Delay(CommandTimeout));
                return done == waiter.Task ? await waiter.Task : "The hub didn't answer. Try again.";
            }
            finally
            {
                lock (_lock)
                    if (_waiting.TryGetValue(key, out var current) && current == waiter)
                        _waiting.Remove(key);
            }
        }

        private void Answer(string key, string? problem)
        {
            TaskCompletionSource<string?>? waiter;
            lock (_lock) _waiting.TryGetValue(key, out waiter);
            waiter?.TrySetResult(problem);
        }

        public IReadOnlyList<HubNodeView> Nodes()
        {
            lock (_lock)
                // Gates, then each sensor board followed by its sensors in order.
                return _nodes.Values
                    .OrderBy(n => n.Kind == HubNodeKind.Gate ? 0 : n.Kind is null ? 2 : 1)
                    .ThenBy(n => HubProtocol.BoardOf(n.Name).Length)
                    .ThenBy(n => HubProtocol.BoardOf(n.Name), StringComparer.Ordinal)
                    .ThenBy(n => n.Name.Length).ThenBy(n => n.Name, StringComparer.Ordinal)
                    .Select(n => new HubNodeView(
                        n.Name, n.Kind, n.Online, n.LastSeenAt, n.WentOfflineAt,
                        n.LastError, n.LastErrorAt, n.LastTapAt,
                        n.Occupied, n.DistanceCm, n.SlotChangedAt))
                    .ToList();
        }

        private Node NodeFor(string name)
        {
            if (!_nodes.TryGetValue(name, out var node))
                _nodes[name] = node = new Node(name);
            return node;
        }

        /// <summary>
        /// Runs <paramref name="work"/> after everything already queued for
        /// the node, in the order the lines arrived, and never on the caller's
        /// thread — that is the port loop, which must get back to reading.
        /// </summary>
        private Task InOrder(string node, CancellationToken ct, Func<CancellationToken, Task> work)
        {
            lock (_lock)
            {
                var before = _queues.TryGetValue(node, out var queued) ? queued : Task.CompletedTask;
                var next = RunAfter(before);
                _queues[node] = next;
                return next;
            }

            async Task RunAfter(Task before)
            {
                await before;
                await Task.Yield();
                try
                {
                    await work(ct);
                }
                catch (Exception ex)
                {
                    // Never fails, so the next in line always runs.
                    if (ex is not OperationCanceledException)
                        _log?.Invoke($"{node}: {ex.Message}");
                }
            }
        }

        private sealed class Node(string name)
        {
            public string Name { get; } = name;
            public HubNodeKind? Kind { get; } = HubProtocol.KindOf(name);
            public bool Online { get; set; }
            public DateTime? LastSeenAt { get; set; }
            public DateTime? WentOfflineAt { get; set; }
            public string? LastError { get; set; }
            public DateTime? LastErrorAt { get; set; }
            public DateTime? LastTapAt { get; set; }
            public bool? Occupied { get; set; }
            public int? DistanceCm { get; set; }
            public DateTime? SlotChangedAt { get; set; }
        }
    }
}
