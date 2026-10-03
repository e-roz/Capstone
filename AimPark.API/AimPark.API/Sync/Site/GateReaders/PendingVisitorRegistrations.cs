namespace AimPark.API.Sync.Site.GateReaders
{
    /// <summary>
    /// An idle visitor card tapped at a gate, waiting for a guard to say who
    /// is in the car.
    /// </summary>
    /// <param name="Node">The wireless board ("G2") on a hub, or null for a USB reader.</param>
    /// <param name="DeviceId">The reader, or the board's stand-in id — what the barrier is opened through.</param>
    public record PendingVisitorRegistration(
        Guid Id, string RfidTagId, string CardLabel, int Gate, string Port, string? Node,
        Guid DeviceId, string? ReaderName, DateTime TappedAt);

    /// <summary>
    /// The visitor cards tapped at a gate that the security screen should be
    /// asking about right now.
    /// </summary>
    /// <remarks>
    /// Held in memory on the site server, never in the database. A gate gives
    /// up on its answer after 15 seconds, so the tap is refused at once and the
    /// barrier is opened later, when the guard saves the form. If the server
    /// restarts in between, the car is still at the barrier and the guard has
    /// the card: tapping again costs nothing, and a stale form for a car that
    /// has since driven off would cost a wrong entry.
    /// </remarks>
    public class PendingVisitorRegistrations
    {
        /// <summary>
        /// Long enough to fill a form while the visitor finds their licence;
        /// short enough that a car that was turned away doesn't linger on
        /// every guard's screen.
        /// </summary>
        public static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(5);

        private readonly object _lock = new();
        private readonly Dictionary<Guid, PendingVisitorRegistration> _pending = new();

        /// <summary>
        /// Records a tap. Tapping the same card again replaces its earlier tap
        /// rather than stacking a second form for the same car.
        /// </summary>
        public PendingVisitorRegistration Add(
            string tag, string label, int gate, string port, string? node, Guid deviceId, string? readerName)
        {
            lock (_lock)
            {
                Purge();

                var earlier = _pending.Values.FirstOrDefault(p => p.RfidTagId == tag);
                var entry = new PendingVisitorRegistration(
                    earlier?.Id ?? Guid.NewGuid(), tag, label, gate, port, node, deviceId, readerName,
                    DateTime.UtcNow);

                _pending[entry.Id] = entry;
                return entry;
            }
        }

        public IReadOnlyList<PendingVisitorRegistration> List()
        {
            lock (_lock)
            {
                Purge();
                return _pending.Values.OrderBy(p => p.TappedAt).ToList();
            }
        }

        /// <summary>
        /// Hands a tap to exactly one guard. Two guards saving the same form
        /// would otherwise lend the card twice.
        /// </summary>
        public PendingVisitorRegistration? Take(Guid id)
        {
            lock (_lock)
            {
                Purge();
                return _pending.Remove(id, out var entry) ? entry : null;
            }
        }

        /// <summary>Puts a tap back after saving it failed, so the guard can fix the form and try again.</summary>
        public void Restore(PendingVisitorRegistration entry)
        {
            lock (_lock)
            {
                if (_pending.Values.All(p => p.RfidTagId != entry.RfidTagId))
                    _pending[entry.Id] = entry;
            }
        }

        private void Purge()
        {
            var cutoff = DateTime.UtcNow - Lifetime;
            foreach (var stale in _pending.Values.Where(p => p.TappedAt < cutoff).ToList())
                _pending.Remove(stale.Id);
        }
    }
}
