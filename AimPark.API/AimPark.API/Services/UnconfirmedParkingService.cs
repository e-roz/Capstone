using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Services
{
    /// <summary>
    /// When leaving without confirming a bay starts to count, read from the
    /// <c>SlotConfirmPolicy</c> section of configuration.
    /// </summary>
    /// <remarks>
    /// Introduced in two steps so nobody is punished by surprise: drivers are
    /// told first, then sessions start to count from <see cref="CountFrom"/> and
    /// only bring warnings, and from <see cref="StrikesFrom"/> a repeat case is
    /// also sent to an admin as a possible strike. Unset, nothing counts.
    /// </remarks>
    public class SlotConfirmPolicyOptions
    {
        public const string Section = "SlotConfirmPolicy";

        /// <summary>Sessions that ended before this are never counted. Null turns the whole thing off.</summary>
        public DateTime? CountFrom { get; set; }

        /// <summary>Before this, only warnings. Null means warnings only, never a review.</summary>
        public DateTime? StrikesFrom { get; set; }
    }

    /// <summary>
    /// Warns a driver who keeps leaving without confirming their bay, and sends
    /// a driver who does it again and again to an admin to decide on a strike.
    /// </summary>
    /// <remarks>
    /// Cloud only, like the confirms it counts. Never issues a violation itself:
    /// the counting cannot tell a dead phone from someone dodging a bay, so a
    /// person reviews the history and decides.
    ///
    /// Each warning and review is sent once per <see cref="SlotConfirmPolicy.Window"/>,
    /// recognised by the notification it produced, so it needs no column of its own.
    /// </remarks>
    public class UnconfirmedParkingService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

        public const string WarningMarker = "\"kind\":\"UnconfirmedWarning\"";
        public const string ReviewMarker = "\"kind\":\"UnconfirmedParking\"";

        private readonly IServiceScopeFactory _scopes;
        private readonly IOptions<SlotConfirmPolicyOptions> _options;
        private readonly ILogger<UnconfirmedParkingService> _logger;

        public UnconfirmedParkingService(
            IServiceScopeFactory scopes,
            IOptions<SlotConfirmPolicyOptions> options,
            ILogger<UnconfirmedParkingService> logger)
        {
            _scopes = scopes;
            _options = options;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try { await Task.Delay(TimeSpan.FromMinutes(2), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);

            do
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();
                    var staff = scope.ServiceProvider.GetRequiredService<IStaffAlerts>();
                    await RunAsync(db, notifications, staff, _options.Value, DateTime.UtcNow, stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Unconfirmed parking pass failed.");
                }
            }
            while (await WaitAsync(timer, stoppingToken));
        }

        private static async Task<bool> WaitAsync(PeriodicTimer timer, CancellationToken ct)
        {
            try { return await timer.WaitForNextTickAsync(ct); }
            catch (OperationCanceledException) { return false; }
        }

        /// <summary>Counted unconfirmed sessions per driver, as of <paramref name="now"/>.</summary>
        public static async Task<Dictionary<Guid, int>> CountAsync(
            AppDbContext db, SlotConfirmPolicyOptions options, DateTime now, CancellationToken ct)
        {
            if (options.CountFrom is not DateTime countFrom) return [];

            var countFromUtc = countFrom.ToUniversalTime();
            var windowStart = now - SlotConfirmPolicy.Window;
            var since = countFromUtc > windowStart ? countFromUtc : windowStart;

            // A driver may confirm until midnight of the day they came in, so
            // only sessions from before today (Manila) are final.
            var today = SlotConfirmPolicy.ManilaDay(now);
            var todayStartUtc = today.ToDateTime(TimeOnly.MinValue, DateTimeKind.Utc).AddHours(-8);

            var sessions = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId != null
                         && l.VisitorPassId == null
                         && l.ExitTime != null
                         && l.SlotConfirmedAt == null
                         && l.EntryTime >= since
                         && l.EntryTime < todayStartUtc)
                .Select(l => new { UserId = l.UserId!.Value, l.EntryTime, ExitTime = l.ExitTime!.Value })
                .ToListAsync(ct);

            return sessions
                .Where(s => SlotConfirmPolicy.Counts(s.UserId, s.EntryTime, s.ExitTime))
                .GroupBy(s => s.UserId)
                .ToDictionary(g => g.Key, g => g.Count());
        }

        /// <summary>One pass. Returns how many warnings and reviews it sent.</summary>
        public static async Task<(int Warned, int Reviewed)> RunAsync(
            AppDbContext db, INotificationService notifications, IStaffAlerts staff,
            SlotConfirmPolicyOptions options, DateTime now, CancellationToken ct)
        {
            var counts = await CountAsync(db, options, now, ct);
            var recent = now - SlotConfirmPolicy.Window;
            var strikesOn = options.StrikesFrom is DateTime s && now >= s.ToUniversalTime();

            var warned = 0;
            var reviewed = 0;
            foreach (var (userId, count) in counts)
            {
                if (count >= SlotConfirmPolicy.ReviewAt && strikesOn)
                {
                    var alreadyReviewed = await db.Set<Notification>().AsNoTracking().AnyAsync(n =>
                        n.TargetRole == UserRole.Admin
                        && n.CreatedAt >= recent
                        && n.Data != null
                        && n.Data.Contains(ReviewMarker)
                        && n.Data.Contains(userId.ToString()), ct);
                    if (!alreadyReviewed)
                    {
                        await staff.RaiseAsync(StaffAlertKind.UnconfirmedParking, userId, ct);
                        await notifications.NotifyUserAsync(
                            userId,
                            NotificationType.Violation,
                            "Sent for review",
                            $"You left without confirming your bay {count} times in the last {SlotConfirmPolicy.Window.Days} days. An admin will review this and may issue a violation.",
                            new Dictionary<string, string> { ["screen"] = "parking-slots", ["kind"] = "UnconfirmedReview" },
                            ct);
                        reviewed++;
                    }
                    continue;
                }

                if (count < SlotConfirmPolicy.WarnAt) continue;

                var alreadyWarned = await db.Set<Notification>().AsNoTracking().AnyAsync(n =>
                    n.TargetUserId == userId
                    && n.CreatedAt >= recent
                    && n.Data != null
                    && n.Data.Contains(WarningMarker), ct);
                if (alreadyWarned) continue;

                var left = SlotConfirmPolicy.ReviewAt - count;
                await notifications.NotifyUserAsync(
                    userId,
                    NotificationType.Reminder,
                    "Confirm your bay each time you park",
                    $"You left without confirming your bay {count} times in the last {SlotConfirmPolicy.Window.Days} days. " +
                    (left > 0
                        ? $"{left} more and it's sent to an admin as a possible strike."
                        : "Next time it's sent to an admin as a possible strike."),
                    new Dictionary<string, string> { ["screen"] = "parking-slots", ["kind"] = "UnconfirmedWarning" },
                    ct);
                warned++;
            }

            return (warned, reviewed);
        }
    }
}
