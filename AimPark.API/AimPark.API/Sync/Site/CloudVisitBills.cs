using System.Net.Http.Json;
using AimPark.API.Entities;

namespace AimPark.API.Sync.Site
{
    /// <summary>Brings one visit's bills over from the cloud, right now.</summary>
    public interface ICloudVisitBills
    {
        Task RefreshAsync(Guid parkingLogId, CancellationToken ct);
    }

    /// <summary>
    /// Asks the cloud for one visit's bills and copies them in, before the gate
    /// holds a driver or a guard takes cash.
    /// </summary>
    /// <remarks>
    /// The snapshot carries app payments to the site too, but only after the
    /// cloud announces a change and the site downloads everything again. A driver
    /// who pays in the app and taps out seconds later can beat it: the gate saw
    /// no payment, raised a second bill for the whole visit, and the guard took
    /// it in cash. This one small request closes that gap.
    ///
    /// Waits a few seconds at most. With the internet down the gate decides on
    /// what it already has, as before.
    /// </remarks>
    public sealed class CloudVisitBills : ICloudVisitBills
    {
        private static readonly TimeSpan Wait = TimeSpan.FromSeconds(3);

        private readonly IHttpClientFactory _http;
        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<CloudVisitBills> _logger;

        public CloudVisitBills(IHttpClientFactory http, IServiceScopeFactory scopes, ILogger<CloudVisitBills> logger)
        {
            _http = http;
            _scopes = scopes;
            _logger = logger;
        }

        public async Task RefreshAsync(Guid parkingLogId, CancellationToken ct)
        {
            List<PaymentTransaction>? bills;
            using (var timeout = CancellationTokenSource.CreateLinkedTokenSource(ct))
            {
                timeout.CancelAfter(Wait);
                try
                {
                    var client = _http.CreateClient(SiteOutboxPusher.CloudClient);
                    bills = await client.GetFromJsonAsync<List<PaymentTransaction>>(
                        $"api/site-sync/visits/{parkingLogId:D}/bills", timeout.Token);
                }
                catch (Exception ex) when (!ct.IsCancellationRequested)
                {
                    _logger.LogWarning("Could not check the cloud for payments on visit {LogId}: {Error}",
                        parkingLogId, ex.Message);
                    return;
                }
            }

            if (bills is null || bills.Count == 0)
                return;

            // Its own scope: the applier marks its save as the cloud's data, and
            // that must not stop the caller's own save reaching the outbox.
            using var scope = _scopes.CreateScope();
            await scope.ServiceProvider.GetRequiredService<SnapshotApplier>().ApplyVisitBillsAsync(bills, ct);
        }
    }
}
