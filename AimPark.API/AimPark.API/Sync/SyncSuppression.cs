namespace AimPark.API.Sync
{
    /// <summary>
    /// Set for the length of a request while it is writing data that came from
    /// the other side, so that write is not echoed straight back.
    /// </summary>
    /// <remarks>
    /// Without it the cloud would store a batch from the site, see the slots
    /// it touched as changed, and tell the site to download everything again —
    /// once per car. The site has the same problem the other way round.
    /// </remarks>
    public class SyncSuppression
    {
        public bool Active { get; set; }
    }

    public static class SitePolicies
    {
        /// <summary>Only a key issued to the site server passes.</summary>
        public const string SiteServer = "SiteServer";
    }
}
