using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Interfaces;

namespace AimPark.API.Services
{
    /// <summary>
    /// Tells security when the cards and the sensors have disagreed for five
    /// minutes: a car parked outside a bay, or one taking two. See
    /// <see cref="ParkingMismatchWatch"/> for when a gap counts.
    /// </summary>
    /// <remarks>
    /// Site only, beside the sensors. The notice names no bay or driver: the
    /// counts cannot say which car, so the guard goes and looks.
    /// </remarks>
    public class ParkingMismatchMonitor : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromSeconds(30);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<ParkingMismatchMonitor> _logger;
        private readonly ParkingMismatchWatch _watch;

        public ParkingMismatchMonitor(
            IServiceScopeFactory scopes, IConfiguration config, ILogger<ParkingMismatchMonitor> logger)
        {
            _scopes = scopes;
            _logger = logger;

            var minutes = config.GetValue<double?>("Parking:MismatchMinutes");
            _watch = new ParkingMismatchWatch(minutes is > 0 ? TimeSpan.FromMinutes(minutes.Value) : null);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Let startup (migrations, the hub) settle before the first look.
            try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);

            do
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var count = await ParkingCapacity.LoadCountAsync(db, stoppingToken);

                    var gap = _watch.Check(count, DateTime.UtcNow);
                    if (gap is not null)
                    {
                        // An alert, not a saved notification: it is the nudge to go
                        // and look, and the gap itself shows on the parking screen.
                        var push = scope.ServiceProvider.GetRequiredService<IPushSender>();
                        var data = new Dictionary<string, string> { ["type"] = "parking_mismatch" };
                        foreach (var role in new[] { UserRole.Security, UserRole.Admin })
                            await push.SendToRoleAsync(role, "Check the lot", Describe(gap.Value, count), data, stoppingToken);
                    }
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Parking mismatch check failed.");
                }
            }
            while (await WaitAsync(timer, stoppingToken));
        }

        internal static string Describe(ParkingMismatch gap, LotCount count) => gap switch
        {
            ParkingMismatch.UnseenCar =>
                $"{count.UsersInside} users are inside but sensors read only {count.SensorsDetected}. " +
                "A car may be parked outside a bay. Please go and check.",
            _ =>
                $"Sensors read {count.SensorsDetected} cars but only {count.UsersInside} users are inside. " +
                "A car may be taking two bays. Please go and check."
        };

        private static async Task<bool> WaitAsync(PeriodicTimer timer, CancellationToken ct)
        {
            try { return await timer.WaitForNextTickAsync(ct); }
            catch (OperationCanceledException) { return false; }
        }
    }
}
