using Microsoft.AspNetCore.SignalR;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>
    /// Tells the site server that something a gate depends on has changed.
    /// </summary>
    /// <remarks>
    /// Waits half a second before sending, and folds everything that happens
    /// in that half second into one message. Approving a registration touches
    /// the user and their vehicles in separate saves; the site should download
    /// once, after both.
    /// </remarks>
    public class MasterDataChangeNotifier
    {
        private static readonly TimeSpan Settle = TimeSpan.FromMilliseconds(500);

        private readonly IHubContext<SiteSyncHub> _hub;
        private readonly ILogger<MasterDataChangeNotifier> _logger;
        private int _scheduled;

        public MasterDataChangeNotifier(IHubContext<SiteSyncHub> hub, ILogger<MasterDataChangeNotifier> logger)
        {
            _hub = hub;
            _logger = logger;
        }

        public void Notify()
        {
            if (Interlocked.Exchange(ref _scheduled, 1) == 1)
                return;

            _ = SendAfterSettleAsync();
        }

        private async Task SendAfterSettleAsync()
        {
            try
            {
                await Task.Delay(Settle);
                Interlocked.Exchange(ref _scheduled, 0);
                await _hub.Clients.All.SendAsync(SiteSyncHub.MasterDataChanged);
            }
            catch (Exception ex)
            {
                // The site also checks on a timer, so a lost message costs
                // minutes, not correctness.
                Interlocked.Exchange(ref _scheduled, 0);
                _logger.LogWarning(ex, "Could not tell the site server that gate data changed.");
            }
        }
    }
}
