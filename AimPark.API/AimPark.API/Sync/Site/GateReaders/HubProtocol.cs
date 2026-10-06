using System.Globalization;
using System.Text.RegularExpressions;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>What a board behind the hub is for, read off its name.</summary>
    public enum HubNodeKind
    {
        /// <summary>G1, G2: a wireless barrier with a card reader.</summary>
        Gate,

        /// <summary>S1/3: one ultrasonic sensor on a sensor board, over one parking slot.</summary>
        Sensor,

        /// <summary>S1, S2: a sensor board. Comes and goes as a whole; its sensors are the slots.</summary>
        SensorBoard
    }

    /// <summary>One line from the hub, understood.</summary>
    public abstract record HubLine;

    /// <summary><c># ...</c> — written for a person on the Serial Monitor.</summary>
    public record HubComment(string Text) : HubLine;

    /// <summary><c>G1 UID:04A1B2C3</c> — a card at a gate, waiting for an answer.</summary>
    public record HubTap(string Node, string Uid) : HubLine;

    /// <summary><c>S1/3 SLOT:OCCUPIED 3.7</c> — a slot changed, or a STATUS reply. Distance rounded to whole cm.</summary>
    public record HubSlot(string Node, bool Occupied, int DistanceCm) : HubLine;

    /// <summary><c>S1/3 SLOT:FAULT 0.0</c> — the sensor hears no echo at all: unplugged or broken. Its board is fine.</summary>
    public record HubSlotFault(string Node) : HubLine;

    /// <summary><c>G1 ONLINE</c> / <c>G1 OFFLINE</c>.</summary>
    public record HubPresence(string Node, bool Online) : HubLine;

    /// <summary><c>G1 ERR:NOT_DELIVERED</c> — something sent to the node never reached it.</summary>
    public record HubNodeError(string Node, string Code) : HubLine;

    /// <summary>Anything else. Logged, never acted on.</summary>
    public record HubUnknown(string Text) : HubLine;

    /// <summary><c>PAIRREQ 582ABDD0A36C GATE</c> — an unpaired board asking to join, by its id (MAC).</summary>
    public record HubPairRequest(string Id, HubNodeKind Kind) : HubLine;

    /// <summary><c>PAIRED G1 582ABDD0A36C GATE</c> — a board the hub knows by that name. Also repeated on STATUS.</summary>
    public record HubPaired(string Node, string Id, HubNodeKind Kind) : HubLine;

    /// <summary><c>FORGOT G1</c> — removed from the hub.</summary>
    public record HubForgot(string Node) : HubLine;

    /// <summary><c>ERR 582ABDD0A36C &lt;why&gt;</c> — a PAIR the hub couldn't do.</summary>
    public record HubCommandError(string Id, string Message) : HubLine;

    /// <summary><c>HUB 20500DCF8718 3</c> — the answer to PING: this hub's id and protocol.</summary>
    public record HubHello(string Id, int Protocol) : HubLine;

    /// <summary>
    /// <c>DIAG G1 rtt=14 rssi=-52 …</c> or <c>DIAG HUB up=… heap=…</c> — the
    /// answer to a connection test, as the hub's key=value pairs.
    /// </summary>
    public record HubDiag(string Node, IReadOnlyDictionary<string, string> Values) : HubLine;

    /// <summary><c>DIAG G1 FAIL NO_REPLY</c> — the connection test didn't reach the board, or it didn't answer.</summary>
    public record HubDiagFailed(string Node, string Code) : HubLine;

    /// <summary>
    /// The ESP-NOW hub's serial protocol (firmware/aimpark_espnow_hub): one
    /// line each way, every line naming the board it is about.
    /// </summary>
    /// <remarks>
    /// Parsing is kept apart from the port so the tests can play the hub's
    /// side without one plugged in.
    /// </remarks>
    public static class HubProtocol
    {
        public const string StatusRequest = "STATUS";

        private const string BannerText = "# AimPark ESP-NOW hub";
        private const string ReadyText = "# Ready";

        // A board ("G1", "S2"), or one sensor on a sensor board ("S2/7").
        private static readonly Regex NodeName = new(@"^[A-Z]+[0-9]+(/[0-9]+)?$", RegexOptions.Compiled);

        /// <summary>The first thing the hub prints after it boots.</summary>
        public static bool IsBanner(string line) => line.Trim().StartsWith(BannerText, StringComparison.Ordinal);

        /// <summary>"# Ready on channel 1. Waiting for nodes." — the hub can take commands.</summary>
        public static bool IsReady(string line) => line.Trim().StartsWith(ReadyText, StringComparison.Ordinal);

        public static string Result(string node, bool opened) => $"{node} RESULT:{(opened ? "OPEN" : "SHUT")}";

        public static string Open(string node) => $"{node} CMD:OPEN";

        public const string Ping = "PING";

        /// <summary>What a connection test of the hub itself is called, in its DIAG lines.</summary>
        public const string HubName = "HUB";

        /// <summary>The hub's own health, or with a board's name, a ping to that board over the air.</summary>
        public static string Diag(string? node = null) => node is null ? "DIAG" : $"DIAG {node}";

        /// <summary>
        /// The hub's "# ERR:UNKNOWN_COMMAND DIAG …": its firmware is older than
        /// the connection test.
        /// </summary>
        public static bool IsUnknownDiag(HubComment comment) =>
            comment.Text.StartsWith("ERR:UNKNOWN_COMMAND DIAG", StringComparison.Ordinal);

        /// <summary>Accepts a board asking to join, and names it (G1, S2).</summary>
        public static string Pair(string id, string node) => $"PAIR {id} {node}";

        public static string Forget(string node) => $"FORGET {node}";

        // A board's id: its MAC as 12 hex digits.
        private static readonly Regex BoardId = new("^[0-9A-F]{12}$", RegexOptions.Compiled);

        // What a paired board may be called: G1–G9 for a gate, S1–S9 for a sensor board.
        private static readonly Regex BoardName = new("^[GS][1-9]$", RegexOptions.Compiled);

        public static bool IsBoardId(string id) => BoardId.IsMatch(id);

        /// <summary>A name the hub would accept for a board of this kind.</summary>
        public static bool FitsName(string node, HubNodeKind kind) =>
            BoardName.IsMatch(node) && KindOf(node) == kind;

        /// <summary>The gate a gate node stands for when nothing else is chosen: G2 is gate 2.</summary>
        public static int? GateOf(string node) =>
            KindOf(node) == HubNodeKind.Gate && int.TryParse(node[1..], out var gate) && gate >= 1 ? gate : null;

        private static HubNodeKind? KindOfRole(string role) => role switch
        {
            "GATE" => HubNodeKind.Gate,
            "SENSOR" => HubNodeKind.SensorBoard,
            _ => null
        };

        /// <summary>The pairing lines, which name a board by id rather than starting with its name.</summary>
        private static HubLine? ParsePairing(string line)
        {
            var parts = line.Split(' ', StringSplitOptions.RemoveEmptyEntries);
            switch (parts[0])
            {
                case "PAIRREQ" when parts.Length == 3 && IsBoardId(parts[1]) && KindOfRole(parts[2]) is { } kind:
                    return new HubPairRequest(parts[1], kind);

                case "PAIRED" when parts.Length == 4 && IsBoardId(parts[2]) && KindOfRole(parts[3]) is { } kind
                                   && FitsName(parts[1].ToUpperInvariant(), kind):
                    return new HubPaired(parts[1].ToUpperInvariant(), parts[2], kind);

                case "FORGOT" when parts.Length == 2:
                    return new HubForgot(parts[1].ToUpperInvariant());

                case "ERR" when parts.Length >= 3 && IsBoardId(parts[1]):
                    return new HubCommandError(parts[1], string.Join(' ', parts[2..]));

                case "HUB" when parts.Length == 3 && IsBoardId(parts[1]) && int.TryParse(parts[2], out var protocol):
                    return new HubHello(parts[1], protocol);

                case "DIAG" when parts.Length >= 4 && parts[2] == "FAIL":
                    return new HubDiagFailed(parts[1].ToUpperInvariant(), parts[3]);

                case "DIAG" when parts.Length >= 2:
                    var values = new Dictionary<string, string>(StringComparer.Ordinal);
                    foreach (var pair in parts[2..])
                    {
                        var eq = pair.IndexOf('=');
                        if (eq > 0) values[pair[..eq]] = pair[(eq + 1)..];
                    }
                    return new HubDiag(parts[1].ToUpperInvariant(), values);

                default:
                    return null;
            }
        }

        public static bool IsNodeName(string node) => NodeName.IsMatch(node);

        /// <summary>
        /// G1 a gate, S1 a sensor board, S1/3 the third sensor on it; null for
        /// a board this server doesn't know.
        /// </summary>
        public static HubNodeKind? KindOf(string node)
        {
            if (node.Length < 2) return null;
            var onBoard = node.Contains('/');
            return node[0] switch
            {
                'G' when !onBoard => HubNodeKind.Gate,
                'S' => onBoard ? HubNodeKind.Sensor : HubNodeKind.SensorBoard,
                _ => null
            };
        }

        /// <summary>The board a sensor sits on: S1 for S1/3. A board is its own.</summary>
        public static string BoardOf(string node)
        {
            var slash = node.IndexOf('/');
            return slash < 0 ? node : node[..slash];
        }

        public static HubLine Parse(string raw)
        {
            var line = raw.Trim();
            if (line.StartsWith('#'))
                return new HubComment(line.TrimStart('#').Trim());

            if (ParsePairing(line) is { } pairing)
                return pairing;

            var space = line.IndexOf(' ');
            if (space <= 0)
                return new HubUnknown(line);

            var node = line[..space].ToUpperInvariant();
            var rest = line[(space + 1)..].Trim();
            if (!IsNodeName(node))
                return new HubUnknown(line);

            if (rest == "ONLINE") return new HubPresence(node, true);
            if (rest == "OFFLINE") return new HubPresence(node, false);

            if (rest.StartsWith("UID:", StringComparison.Ordinal))
            {
                var uid = rest[4..].Trim();
                return uid.Length == 0 ? new HubUnknown(line) : new HubTap(node, uid);
            }

            if (rest.StartsWith("ERR:", StringComparison.Ordinal))
                return new HubNodeError(node, rest[4..].Trim());

            if (rest.StartsWith("SLOT:", StringComparison.Ordinal))
            {
                // "OCCUPIED 3.7", "FREE 0.0" or "FAULT 0.0". The distance is a nicety; the word is the reading.
                if (KindOf(node) != HubNodeKind.Sensor) return new HubUnknown(line);
                var parts = rest[5..].Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 0) return new HubUnknown(line);
                if (parts[0] == "FAULT") return new HubSlotFault(node);

                bool occupied;
                if (parts[0] == "OCCUPIED") occupied = true;
                else if (parts[0] == "FREE") occupied = false;
                else return new HubUnknown(line);

                var distance = parts.Length > 1
                    && double.TryParse(parts[1], NumberStyles.Float, CultureInfo.InvariantCulture, out var cm)
                    && cm >= 0
                        ? (int)Math.Round(cm, MidpointRounding.AwayFromZero)
                        : 0;
                return new HubSlot(node, occupied, distance);
            }

            return new HubUnknown(line);
        }
    }
}
