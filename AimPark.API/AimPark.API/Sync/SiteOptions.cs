namespace AimPark.API.Sync
{
    /// <summary>
    /// Which half of the system this process is.
    /// </summary>
    public enum SiteMode
    {
        /// <summary>
        /// The hosted API: registration, user data, the mobile app, the admin
        /// panel. Stores what the site server sends up and tells it when
        /// anything a gate depends on has changed.
        /// </summary>
        Cloud,

        /// <summary>
        /// The server on the school's own network. Makes every gate decision
        /// from its own copy of the data, so the barrier never waits on the
        /// internet.
        /// </summary>
        Site
    }

    /// <summary>
    /// The <c>Site</c> section of configuration. Everything defaults to the
    /// cloud behaving exactly as it did before the site server existed.
    /// </summary>
    public class SiteOptions
    {
        public const string SectionName = "Site";

        public SiteMode Mode { get; set; } = SiteMode.Cloud;

        /// <summary>Site mode: the cloud API's address, e.g. https://aimpark-api.onrender.com.</summary>
        public string CloudBaseUrl { get; set; } = string.Empty;

        /// <summary>
        /// Site mode: the key issued to this server by
        /// <c>POST /api/admin/gate-devices</c> with <c>deviceType: SiteServer</c>.
        /// </summary>
        public string CloudApiKey { get; set; } = string.Empty;

        /// <summary>
        /// Site mode: folder holding the admin panel's web build, served from
        /// this server so the guard post can open it on the local network.
        /// Empty serves nothing.
        /// </summary>
        public string AdminWebPath { get; set; } = string.Empty;

        /// <summary>
        /// Cloud mode: whether the cloud still accepts gate traffic itself
        /// (entry, exit, plate reads). True until the site server is live, so
        /// nothing stops working during the move. Set false once every reader
        /// points at the site server — after that, a device still aimed at the
        /// cloud would record entries the site knows nothing about.
        /// </summary>
        public bool CloudGateEndpointsEnabled { get; set; } = true;

        public bool IsSite => Mode == SiteMode.Site;

        public bool IsCloud => Mode == SiteMode.Cloud;
    }
}
