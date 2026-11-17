using AimPark.API.Sync;
using AimPark.API.Sync.Cloud;
using Microsoft.Extensions.Options;

namespace AimPark.API.Services
{
    /// <summary>
    /// Whether the bay sensors can be trusted right now. In the cloud they are
    /// only as fresh as the guard post that forwards them; at the guard post
    /// they are read directly, so they are never "silent" there.
    /// </summary>
    public interface ISensorFeed
    {
        /// <summary>True when the guard post has gone quiet, so every bay should be read as No signal.</summary>
        bool IsSilent { get; }
    }

    /// <summary>
    /// The one place that decides "the guard post has gone quiet". The phone's
    /// map and the bay confirm both use it, so a bay the map shows as No signal
    /// is never refused by the server as "empty".
    /// </summary>
    public class GuardPostFeed : ISensorFeed
    {
        /// <summary>
        /// Without a word from the guard post for this long, the bays are not
        /// trusted. The guard post reports every 15 s; the admin map uses the
        /// same 60 s.
        /// </summary>
        public static readonly TimeSpan SilentAfter = TimeSpan.FromSeconds(60);

        // The real process start, not "the first time this class was touched",
        // which a lazy static field would give.
        private static readonly DateTime ProcessStartedAt =
            System.Diagnostics.Process.GetCurrentProcess().StartTime.ToUniversalTime();

        private readonly SiteLinkState _link;
        private readonly SiteOptions _site;

        public GuardPostFeed(SiteLinkState link, IOptions<SiteOptions> site)
        {
            _link = link;
            _site = site.Value;
        }

        /// <summary>When the guard post last reported, by the cloud's clock. Null if never heard since start.</summary>
        public DateTime? LastHeardAt
        {
            get
            {
                var link = _link.Snapshot();
                return new[] { link.LastPushAt, link.HealthAt }.Max();
            }
        }

        public bool IsSilent
        {
            get
            {
                // At the guard post the sensors are read directly; there is no link to be silent.
                if (!_site.IsCloud) return false;

                var heardAt = LastHeardAt;

                // What the cloud has heard is held in memory, and a restart
                // forgets it. The guard post reports at least every 15 seconds,
                // so if the cloud has been up longer than the silence window and
                // heard nothing, it is off.
                return heardAt is null
                    ? _site.TreatUnheardGuardPostAsSilent
                      || DateTime.UtcNow - ProcessStartedAt > SilentAfter
                    : DateTime.UtcNow - heardAt.Value > SilentAfter;
            }
        }
    }
}
