namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// What the cloud knows about the guard post right now: whether its
    /// standing connection is open, when it last sent gate records, and the
    /// latest copy of its device list.
    /// </summary>
    /// <remarks>
    /// The admin panel's parking map reads the cloud, never the guard post, so
    /// without this it could only say when <em>it</em> last asked — and showed
    /// "Live" over data that stopped changing the moment the guard post lost
    /// its internet.
    ///
    /// Held in memory: a restart forgets it, and the guard post puts it back
    /// within seconds by reconnecting and sending its next health report.
    /// </remarks>
    public class SiteLinkState
    {
        private readonly object _lock = new();

        // A reconnect can open the new connection before the old one is
        // reported closed, so count them rather than keep one flag.
        private readonly HashSet<string> _connections = [];

        private DateTime? _connectedSince;
        private DateTime? _disconnectedAt;
        private DateTime? _lastPushAt;
        private DateTime? _healthAt;
        private IReadOnlyList<DeviceHealth> _devices = [];

        public void Connected(string connectionId)
        {
            lock (_lock)
            {
                if (_connections.Count == 0)
                    _connectedSince = DateTime.UtcNow;
                _connections.Add(connectionId);
            }
        }

        public void Disconnected(string connectionId)
        {
            lock (_lock)
            {
                if (_connections.Remove(connectionId) && _connections.Count == 0)
                    _disconnectedAt = DateTime.UtcNow;
            }
        }

        /// <summary>Gate records arrived.</summary>
        public void Pushed()
        {
            lock (_lock)
                _lastPushAt = DateTime.UtcNow;
        }

        public void Health(IReadOnlyList<DeviceHealth> devices)
        {
            lock (_lock)
            {
                _devices = devices;
                // When it arrived, not when the guard post says it checked: the
                // guard PC's clock is not the one the panel compares against.
                _healthAt = DateTime.UtcNow;
            }
        }

        public SiteLinkSnapshot Snapshot()
        {
            lock (_lock)
                return new SiteLinkSnapshot(
                    _connections.Count > 0, _connectedSince, _disconnectedAt,
                    _lastPushAt, _healthAt, _devices);
        }
    }

    public record SiteLinkSnapshot(
        bool Connected,
        DateTime? ConnectedSince,
        DateTime? DisconnectedAt,
        DateTime? LastPushAt,
        DateTime? HealthAt,
        IReadOnlyList<DeviceHealth> Devices);
}
