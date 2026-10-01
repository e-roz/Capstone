using System.Text.RegularExpressions;

namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>What a board behind the hub is for, read off its name.</summary>
    public enum HubNodeKind
    {
        /// <summary>G1, G2: a wireless barrier with a card reader.</summary>
        Gate,

        /// <summary>S1, S2: an ultrasonic sensor over one parking slot.</summary>
        Sensor
    }

    /// <summary>One line from the hub, understood.</summary>
    public abstract record HubLine;

    /// <summary><c># ...</c> — written for a person on the Serial Monitor.</summary>
    public record HubComment(string Text) : HubLine;

    /// <summary><c>G1 UID:04A1B2C3</c> — a card at a gate, waiting for an answer.</summary>
    public record HubTap(string Node, string Uid) : HubLine;

    /// <summary><c>S1 SLOT:OCCUPIED 7</c> — a slot changed, or a STATUS reply.</summary>
    public record HubSlot(string Node, bool Occupied, int DistanceCm) : HubLine;

    /// <summary><c>G1 ONLINE</c> / <c>G1 OFFLINE</c>.</summary>
    public record HubPresence(string Node, bool Online) : HubLine;

    /// <summary><c>G1 ERR:NOT_DELIVERED</c> — something sent to the node never reached it.</summary>
    public record HubNodeError(string Node, string Code) : HubLine;

    /// <summary>Anything else. Logged, never acted on.</summary>
    public record HubUnknown(string Text) : HubLine;

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

        private static readonly Regex NodeName = new(@"^[A-Z]+[0-9]+$", RegexOptions.Compiled);

        /// <summary>The first thing the hub prints after it boots.</summary>
        public static bool IsBanner(string line) => line.Trim().StartsWith(BannerText, StringComparison.Ordinal);

        /// <summary>"# Ready on channel 1. Waiting for nodes." — the hub can take commands.</summary>
        public static bool IsReady(string line) => line.Trim().StartsWith(ReadyText, StringComparison.Ordinal);

        public static string Result(string node, bool opened) => $"{node} RESULT:{(opened ? "OPEN" : "SHUT")}";

        public static string Open(string node) => $"{node} CMD:OPEN";

        public static bool IsNodeName(string node) => NodeName.IsMatch(node);

        /// <summary>G for a gate, S for a sensor; null for a board this server doesn't know.</summary>
        public static HubNodeKind? KindOf(string node) => node.Length < 2 ? null : node[0] switch
        {
            'G' => HubNodeKind.Gate,
            'S' => HubNodeKind.Sensor,
            _ => null
        };

        public static HubLine Parse(string raw)
        {
            var line = raw.Trim();
            if (line.StartsWith('#'))
                return new HubComment(line.TrimStart('#').Trim());

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
                // "OCCUPIED 7" or "FREE 0". The distance is a nicety; the word is the reading.
                var parts = rest[5..].Split(' ', StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 0) return new HubUnknown(line);

                bool occupied;
                if (parts[0] == "OCCUPIED") occupied = true;
                else if (parts[0] == "FREE") occupied = false;
                else return new HubUnknown(line);

                var distance = parts.Length > 1 && int.TryParse(parts[1], out var cm) && cm >= 0 ? cm : 0;
                return new HubSlot(node, occupied, distance);
            }

            return new HubUnknown(line);
        }
    }
}
