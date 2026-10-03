using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    /// <summary>
    /// Closes violations nobody appealed: once the appeal deadline passes, an
    /// Issued violation becomes Accountable, its fine is raised, and the
    /// three-strike check runs.
    /// </summary>
    /// <remarks>
    /// Without it a violation the user ignored stayed Issued forever — open on
    /// their record, never counted, never fined. Cloud only, like the other
    /// clock-driven work. Each pass takes every overdue violation, not just the
    /// last hour's, so a host that slept through a deadline catches up on wake
    /// rather than missing it.
    /// </remarks>
    public class ViolationDeadlineService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromMinutes(15);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<ViolationDeadlineService> _logger;

        public ViolationDeadlineService(IServiceScopeFactory scopes, ILogger<ViolationDeadlineService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Let startup (migrations, Firebase) settle before the first pass.
            try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);

            do
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var violations = scope.ServiceProvider.GetRequiredService<IViolationService>();
                    var count = await violations.PromoteLapsedAsync(DateTime.UtcNow, stoppingToken);
                    if (count > 0)
                        _logger.LogInformation("{Count} violation(s) passed their appeal deadline and are now Accountable.", count);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Violation deadline pass failed.");
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
