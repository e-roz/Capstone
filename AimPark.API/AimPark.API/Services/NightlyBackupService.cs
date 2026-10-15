using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    /// <summary>
    /// Takes a backup every night at 2 AM Manila time and keeps the last 14.
    /// </summary>
    /// <remarks>
    /// Cloud only. 2 AM is when nobody is parking, so the read of every table
    /// costs nothing the gate would notice. A run missed because the API was
    /// down or redeploying is made up for at the next start, when the newest
    /// nightly copy is more than 20 hours old.
    /// </remarks>
    public class NightlyBackupService : BackgroundService
    {
        private const int Keep = 14;

        /// <summary>2 AM in Manila (UTC+8, no daylight saving) is 18:00 UTC.</summary>
        private static readonly TimeSpan RunAtUtc = TimeSpan.FromHours(18);

        private static readonly TimeSpan StaleAfter = TimeSpan.FromHours(20);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<NightlyBackupService> _logger;

        public NightlyBackupService(IServiceScopeFactory scopes, ILogger<NightlyBackupService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try { await Task.Delay(TimeSpan.FromMinutes(3), stoppingToken); }
            catch (OperationCanceledException) { return; }

            var catchUp = true;

            while (!stoppingToken.IsCancellationRequested)
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var backups = scope.ServiceProvider.GetRequiredService<IBackupService>();

                    var last = catchUp ? await backups.LastScheduledAtAsync(stoppingToken) : null;
                    var due = !catchUp || last is null || DateTime.UtcNow - last > StaleAfter;

                    if (due) await backups.CreateScheduledAsync(Keep, stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    _logger.LogError(ex, "Nightly backup failed.");
                }

                catchUp = false;

                try { await Task.Delay(UntilNextRun(DateTime.UtcNow), stoppingToken); }
                catch (OperationCanceledException) { return; }
            }
        }

        public static TimeSpan UntilNextRun(DateTime nowUtc)
        {
            var next = nowUtc.Date + RunAtUtc;
            if (next <= nowUtc) next = next.AddDays(1);
            return next - nowUtc;
        }
    }
}
