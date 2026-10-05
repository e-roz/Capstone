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
    ///
    /// The line being open is also the cloud's best sign the guard post is up,
    /// so its opening and closing are recorded in <see cref="SiteLinkState"/>.
    /// </remarks>
    [Authorize(AuthenticationSchemes = ApiKeyDefaults.AuthenticationScheme, Policy = SitePolicies.SiteServer)]
    public class SiteSyncHub : Hub
    {
        public const string Path = "/hubs/site-sync";

        public const string MasterDataChanged = nameof(MasterDataChanged);

        private readonly SiteLinkState _link;

        public SiteSyncHub(SiteLinkState link)
        {
            _link = link;
        }

        public override Task OnConnectedAsync()
        {
            _link.Connected(Context.ConnectionId);
            return base.OnConnectedAsync();
        }

        public override Task OnDisconnectedAsync(Exception? exception)
        {
            _link.Disconnected(Context.ConnectionId);
            return base.OnDisconnectedAsync(exception);
        }
    }
}
