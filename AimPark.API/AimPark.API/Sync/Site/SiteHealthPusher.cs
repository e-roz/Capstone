using System.Net.Http.Json;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// Sends the guard post's device list to the cloud: as soon as something
    /// changes, and every 15 seconds regardless.
    /// </summary>
    /// <remarks>
    /// The online panel can't reach the guard post — it sits behind the
    /// school's router — so without this every reader, camera and sensor read
    /// "unknown" there. The regular send doubles as the guard post saying "I
    /// am still here", which is what lets the panel warn when its parking map
    /// has stopped updating.
    ///
    /// A failed send is only logged: the next tick tries again, and nothing at
    /// the gates waits on it.
    /// </remarks>
    public class SiteHealthPusher : BackgroundService
    {
        private static readonly TimeSpan CheckEvery = TimeSpan.FromSeconds(3);
        private static readonly TimeSpan SendAtLeastEvery = TimeSpan.FromSeconds(15);

        private readonly IServiceScopeFactory _scopes;
        private readonly IHttpClientFactory _http;
        private readonly ILogger<SiteHealthPusher> _logger;

        public SiteHealthPusher(
            IServiceScopeFactory scopes,
            IHttpClientFactory http,
            ILogger<SiteHealthPusher> logger)
        {
            _scopes = scopes;
            _http = http;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            string? lastSent = null;
            var lastSentAt = DateTime.MinValue;
            var failing = false;

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var report = await scope.ServiceProvider
                        .GetRequiredService<DeviceHealthReport>()
                        .BuildAsync(stoppingToken);

                    var signature = Signature(report);
                    if (signature != lastSent || DateTime.UtcNow - lastSentAt >= SendAtLeastEvery)
                    {
                        var client = _http.CreateClient(SiteOutboxPusher.CloudClient);
                        using var response = await client.PostAsJsonAsync(
                            "api/site-sync/health", report, stoppingToken);

                        if (!response.IsSuccessStatusCode)
                            throw new HttpRequestException(
                                $"Cloud answered {(int)response.StatusCode} to the health report.");

                        lastSent = signature;
                        lastSentAt = DateTime.UtcNow;
                        failing = false;
                    }
                }
                catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
                {
                    return;
                }
                catch (Exception ex)
                {
                    // Once per outage, not every three seconds of one.
                    if (!failing)
                        _logger.LogWarning("Could not send device health to the cloud yet: {Error}", ex.Message);
                    failing = true;
                }

                try
                {
                    await Task.Delay(CheckEvery, stoppingToken);
                }
                catch (OperationCanceledException)
                {
                    return;
                }
            }
        }

        /// <summary>
        /// What a change looks like: a device going up or down, a new error, a
        /// sensor seeing a car. Last-seen times move every few seconds on their
        /// own, so they are left out — the 15-second send carries them.
        /// </summary>
        private static string Signature(SiteHealthReport report) => string.Join('|',
            report.Devices.Select(d => $"{d.Id}:{d.Online}:{d.Bound}:{d.BoundTo}:{d.LastError}:{d.Occupied}"));
    }
}
