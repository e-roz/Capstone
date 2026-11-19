using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    /// <summary>
    /// Works through the "archive when clear" list of the latest bulk archive:
    /// warns people who have become clear, archives them once their notice
    /// is up, and drops anyone who parked again.
    /// </summary>
    /// <remarks>
    /// Cloud only, like <see cref="NotificationReminderService"/>: accounts
    /// live in the cloud and the site server receives the change by sync. The
    /// rules are in <see cref="AdminUserService.RunAutoArchivePassAsync"/>.
    /// On a host that sleeps when idle it runs when the API next wakes, so a
    /// notice or archive can be late, never early.
    /// </remarks>
    public class AutoArchiveService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<AutoArchiveService> _logger;

        public AutoArchiveService(IServiceScopeFactory scopes, ILogger<AutoArchiveService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Let startup (migrations, Firebase) settle before the first pass.
            try { await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);
            do
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var service = scope.ServiceProvider.GetRequiredService<IAdminUserService>();
                    var archived = await service.RunAutoArchivePassAsync(DateTime.UtcNow, stoppingToken);
                    if (archived > 0)
                        _logger.LogInformation("Auto-archive archived {Count} account(s).", archived);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Auto-archive pass failed.");
                }
            }
            while (await WaitAsync(timer, stoppingToken));
        }

        private static async Task<bool> WaitAsync(PeriodicTimer timer, CancellationToken ct)
        {
            try { return await timer.WaitForNextTickAsync(ct); }
            catch (OperationCanceledException) { return false; }
        }
    }
}
