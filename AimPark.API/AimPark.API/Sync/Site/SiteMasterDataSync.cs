using System.Net.Http.Json;
using AimPark.API.Auth;
using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.SignalR.Client;
using Microsoft.Extensions.Options;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// Keeps the site server's copy of the gate data current: holds a line
    /// open to the cloud and downloads a fresh copy the moment the cloud says
    /// something changed.
    /// </summary>
    /// <remarks>
    /// Also downloads when the line comes back after a drop — anything changed
    /// while it was down was never announced — and every few minutes
    /// regardless, in case an announcement went missing.
    ///
    /// While the internet is down the gates carry on with the last copy. A
    /// suspension made in that window takes effect when the line returns.
    /// </remarks>
    public class SiteMasterDataSync : BackgroundService
    {
        private static readonly TimeSpan SafetyNet = TimeSpan.FromMinutes(5);

        private readonly IServiceScopeFactory _scopes;
        private readonly IHttpClientFactory _http;
        private readonly SnapshotSignal _signal;
        private readonly SiteSyncStatus _status;
        private readonly SiteOptions _options;
        private readonly ILogger<SiteMasterDataSync> _logger;

        public SiteMasterDataSync(
            IServiceScopeFactory scopes,
            IHttpClientFactory http,
            SnapshotSignal signal,
            SiteSyncStatus status,
            IOptions<SiteOptions> options,
            ILogger<SiteMasterDataSync> logger)
        {
            _scopes = scopes;
            _http = http;
            _signal = signal;
            _status = status;
            _options = options.Value;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            await using var connection = new HubConnectionBuilder()
                .WithUrl(new Uri(new Uri(_options.CloudBaseUrl), SiteSyncHub.Path), o =>
                    o.Headers[ApiKeyDefaults.HeaderName] = _options.CloudApiKey)
                .WithAutomaticReconnect(new KeepTrying())
                .Build();

            connection.On(SiteSyncHub.MasterDataChanged, () => _signal.Poke());

            connection.Reconnecting += _ =>
            {
                _status.CloudConnected = false;
                return Task.CompletedTask;
            };

            connection.Reconnected += _ =>
            {
                _status.CloudConnected = true;
                _signal.Poke();
                return Task.CompletedTask;
            };

            connection.Closed += _ =>
            {
                _status.CloudConnected = false;
                return Task.CompletedTask;
            };

            await Task.WhenAll(
                StayConnectedAsync(connection, stoppingToken),
                DownloadLoopAsync(stoppingToken));
        }

        /// <summary>
        /// Automatic reconnect only covers a line that was up once. This covers
        /// the first connection, and one that gave up — e.g. the server started
        /// while the school's internet was down.
        /// </summary>
        private async Task StayConnectedAsync(HubConnection connection, CancellationToken ct)
        {
            var retry = new KeepTrying();
            var attempt = 0;

            while (!ct.IsCancellationRequested)
            {
                if (connection.State == HubConnectionState.Disconnected)
                {
                    try
                    {
                        await connection.StartAsync(ct);
                        attempt = 0;
                        _status.CloudConnected = true;
                        _signal.Poke();
                    }
                    catch (OperationCanceledException) when (ct.IsCancellationRequested)
                    {
                        return;
                    }
                    catch (Exception ex)
                    {
                        _status.CloudConnected = false;
                        _logger.LogWarning("Cannot reach the cloud yet: {Error}", ex.Message);
                        attempt++;
                    }
                }

                var wait = connection.State == HubConnectionState.Disconnected
                    ? retry.Delay(attempt)
                    : TimeSpan.FromSeconds(10);

                try { await Task.Delay(wait, ct); }
                catch (OperationCanceledException) { return; }
            }
        }

        private async Task DownloadLoopAsync(CancellationToken ct)
        {
            while (!ct.IsCancellationRequested)
            {
                try
                {
                    await DownloadAsync(ct);
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception ex)
                {
                    _status.LastSnapshotError = ex.Message;
                    _logger.LogWarning("Could not refresh gate data from the cloud: {Error}", ex.Message);
                }

                try
                {
                    await _signal.WaitAsync(SafetyNet, ct);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
            }
        }

        private async Task DownloadAsync(CancellationToken ct)
        {
            var client = _http.CreateClient(SiteOutboxPusher.CloudClient);
            var snapshot = await client.GetFromJsonAsync<SiteSnapshot>("api/site-sync/snapshot", ct)
                ?? throw new InvalidOperationException("The cloud sent an empty snapshot.");

            using var scope = _scopes.CreateScope();
            await scope.ServiceProvider.GetRequiredService<SnapshotApplier>().ApplyAsync(snapshot, ct);

            _status.LastSnapshotAt = DateTime.UtcNow;
            _status.LastSnapshotError = null;
        }

        /// <summary>1, 2, 4 … up to 30 seconds between tries, forever.</summary>
        private sealed class KeepTrying : IRetryPolicy
        {
            public TimeSpan? NextRetryDelay(RetryContext retryContext) => Delay((int)retryContext.PreviousRetryCount);

            public TimeSpan Delay(int attempt) => TimeSpan.FromSeconds(Math.Min(30, Math.Pow(2, Math.Min(attempt, 5))));
        }
    }
}
