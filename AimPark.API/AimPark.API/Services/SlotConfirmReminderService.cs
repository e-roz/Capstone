using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Asks a driver who is still inside, and has not said which bay they are
    /// in, to do so. One reminder per session.
    /// </summary>
    /// <remarks>
    /// Cloud only, like <see cref="NotificationReminderService"/>: the phones are
    /// here. It has its own, shorter, timer because ten minutes after tapping in
    /// is the point of the reminder, and an hourly pass would send it late.
    ///
    /// Whether a session has had its reminder is read from the notification it
    /// produced rather than stamped on the parking log, so it needs no column on
    /// a table the site server also writes.
    /// </remarks>
    public class SlotConfirmReminderService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromMinutes(1);

        /// <summary>Long enough to have found a bay and walked away from it.</summary>
        public static readonly TimeSpan WaitBeforeReminding = TimeSpan.FromMinutes(10);

        /// <summary>
        /// A session still "open" after this long is more likely forgotten than
        /// parked, and the first pass after deploying would otherwise nag every
        /// stale row.
        /// </summary>
        public static readonly TimeSpan GiveUpAfter = TimeSpan.FromHours(6);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<SlotConfirmReminderService> _logger;

        public SlotConfirmReminderService(
            IServiceScopeFactory scopes,
            ILogger<SlotConfirmReminderService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            try { await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken); }
            catch (OperationCanceledException) { return; }

            using var timer = new PeriodicTimer(Interval);

            do
            {
                try
                {
                    using var scope = _scopes.CreateScope();
                    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                    var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();
                    await RemindAsync(db, notifications, DateTime.UtcNow, stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Slot confirm reminder pass failed.");
                }
            }
            while (await WaitAsync(timer, stoppingToken));
        }

        private static async Task<bool> WaitAsync(PeriodicTimer timer, CancellationToken ct)
        {
            try { return await timer.WaitForNextTickAsync(ct); }
            catch (OperationCanceledException) { return false; }
        }

        /// <summary>One pass. Returns how many reminders it sent.</summary>
        public static async Task<int> RemindAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            var remindBefore = now - WaitBeforeReminding;
            var notOlderThan = now - GiveUpAfter;

            var due = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId != null
                         && l.ExitTime == null
                         && l.SlotConfirmedAt == null
                         && l.EntryTime <= remindBefore
                         && l.EntryTime >= notOlderThan)
                .Select(l => new { l.Id, UserId = l.UserId!.Value })
                .ToListAsync(ct);

            var sent = 0;
            foreach (var log in due)
            {
                var marker = $"\"logId\":\"{log.Id}\"";
                var already = await db.Set<Notification>().AsNoTracking().AnyAsync(n =>
                    n.TargetUserId == log.UserId
                    && n.Type == NotificationType.Reminder
                    && n.Data != null && n.Data.Contains(marker), ct);
                if (already) continue;

                await notifications.NotifyUserAsync(
                    log.UserId,
                    NotificationType.Reminder,
                    "Where did you park?",
                    "Tap your bay on the map so the guards know it was you.",
                    new Dictionary<string, string>
                    {
                        ["screen"] = "parking-slots",
                        ["logId"] = log.Id.ToString(),
                    },
                    ct);
                sent++;
            }

            return sent;
        }
    }
}
