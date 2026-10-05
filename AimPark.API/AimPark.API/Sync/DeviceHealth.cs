namespace AimPark.API.Sync
{
    /// <summary>
    /// One device the guard post depends on, as the site server sees it: the
    /// hub and the boards behind it, the USB readers, each gate's camera, and
    /// the link to the cloud.
    /// </summary>
    /// <remarks>
    /// Shared by both ends: the site builds it (<see cref="Site.DeviceHealthReport"/>),
    /// shows it on the guard post's panel, and sends it to the cloud, which
    /// keeps the latest copy for the online panel (<see cref="Cloud.SiteLinkState"/>).
    /// </remarks>
    public record DeviceHealth(
        string Id,
        string Name,
        string Kind,
        string? BoundTo,
        bool Bound,
        bool Online,
        DateTime? LastSeenAt,
        string? LastError,
        DateTime? LastErrorAt,
        string? DependsOn = null,
        string? Detail = null,
        bool? Occupied = null,
        int? DistanceCm = null);

    /// <summary>What the site sends to <c>POST /api/site-sync/health</c>.</summary>
    public class SiteHealthReport
    {
        public DateTime CheckedAt { get; set; }
        public List<DeviceHealth> Devices { get; set; } = [];
    }
}
