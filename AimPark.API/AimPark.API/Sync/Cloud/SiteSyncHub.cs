using AimPark.API.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// The site server's standing connection to the cloud.
    /// </summary>
    /// <remarks>
    /// The site sits behind the school's router, so the cloud cannot call it —
    /// the site has to call out and hold the line open. Only one message ever
    /// goes down it, <see cref="MasterDataChanged"/>, and it carries no data:
    /// the site answers it by downloading the snapshot, which is the one place
    /// the data is read from.
    /// </remarks>
    [Authorize(AuthenticationSchemes = ApiKeyDefaults.AuthenticationScheme, Policy = SitePolicies.SiteServer)]
    public class SiteSyncHub : Hub
    {
        public const string Path = "/hubs/site-sync";

        public const string MasterDataChanged = nameof(MasterDataChanged);
    }
}
