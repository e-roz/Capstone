namespace AimPark.API.Services
{
    /// <summary>
    /// Holds the last card tapped on an enrollment reader, so the admin panel
    /// can pick it up on its next poll.
    /// </summary>
    /// <remarks>
    /// Deliberately in memory and deliberately one slot deep. A tap is only
    /// interesting for the few seconds an admin is looking at the Assign
    /// dialog; keeping a history would mean a table, a migration and a cleanup
    /// job for data that is worthless a minute after it is written. Losing the
    /// buffer on restart costs one re-tap.
    ///
    /// The trade-off this accepts: it is per-process, so it works for the
    /// single local API the enrollment desk runs against and would need to move
    /// to the database if the API were ever scaled to several instances.
    /// </remarks>
    public class RfidScanBuffer
    {
        /// <summary>
        /// How long a tap stays offerable. Long enough to cover an admin
        /// tapping before they open the dialog, short enough that a card left
        /// on the reader from an earlier session is never assigned by accident.
        /// </summary>
        public static readonly TimeSpan Freshness = TimeSpan.FromMinutes(2);

        private readonly object _gate = new();
        private RfidScan? _latest;

        public void Record(string rfidTagId, Guid deviceId, string deviceName)
        {
            var scan = new RfidScan(Guid.NewGuid(), rfidTagId, DateTime.UtcNow, deviceId, deviceName);
            lock (_gate) _latest = scan;
        }

        /// <summary>The last tap, or null if there is none or it has gone stale.</summary>
        public RfidScan? Latest()
        {
            lock (_gate)
            {
                if (_latest is null) return null;
                return DateTime.UtcNow - _latest.ScannedAt > Freshness ? null : _latest;
            }
        }
    }

    public record RfidScan(
        Guid ScanId,
        string RfidTagId,
        DateTime ScannedAt,
        Guid DeviceId,
        string DeviceName);
}
