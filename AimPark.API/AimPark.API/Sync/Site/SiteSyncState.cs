namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// A wake-up call between a request and a background loop: "there is work,
    /// don't wait for your timer". Pokes that arrive while the loop is busy
    /// fold into one.
    /// </summary>
    public abstract class SyncSignal
    {
        private readonly SemaphoreSlim _gate = new(0, 1);

        public void Poke()
        {
            try { _gate.Release(); }
            catch (SemaphoreFullException) { /* already poked */ }
        }

        /// <summary>Returns when poked, or when <paramref name="timeout"/> passes.</summary>
        public Task WaitAsync(TimeSpan timeout, CancellationToken ct) => _gate.WaitAsync(timeout, ct);
    }

    /// <summary>Something new is in the outbox.</summary>
    public class OutboxSignal : SyncSignal { }

    /// <summary>The cloud says gate data changed.</summary>
    public class SnapshotSignal : SyncSignal { }

    /// <summary>
    /// How the site server's link to the cloud is doing, for
    /// <c>GET /api/site/status</c>. Nothing here is needed to make a gate
    /// decision — it is for whoever is troubleshooting the guard post.
    /// </summary>
    public class SiteSyncStatus
    {
        public bool CloudConnected { get; set; }
        public DateTime? LastSnapshotAt { get; set; }
        public string? LastSnapshotError { get; set; }
        public DateTime? LastPushAt { get; set; }
        public string? LastPushError { get; set; }
    }
}
