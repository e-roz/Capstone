using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// The notifications nobody presses a button for: a bill due tomorrow, a
    /// bill gone overdue, a suspension starting, access coming back.
    /// </summary>
    /// <remarks>
    /// Every other push is raised by an action — a tap at the gate, an admin
    /// issuing a violation. These are raised by the clock, so something has to
    /// watch it. Cloud only: the site server has no phones to reach and hands
    /// its pushes to the cloud anyway.
    ///
    /// Each notice is stamped on the row it is about, so a restart or a second
    /// pass within the hour never sends one twice. On a host that sleeps when
    /// idle (Render's free tier) it simply runs when the API next wakes, which
    /// is late rather than lost.
    /// </remarks>
    public class NotificationReminderService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromHours(1);

        /// <summary>
        /// How far back an overdue bill or a started suspension can be and
        /// still earn a notice. Without it the first run after deploying would
        /// send a notice for every unpaid bill in the database's history.
        /// </summary>
        private static readonly TimeSpan CatchUpWindow = TimeSpan.FromDays(3);

        /// <summary>A phone not seen for this long has almost surely been wiped or replaced.</summary>
        private static readonly TimeSpan DeviceTokenLifetime = TimeSpan.FromDays(60);

        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<NotificationReminderService> _logger;

        public NotificationReminderService(
            IServiceScopeFactory scopes,
            ILogger<NotificationReminderService> logger)
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
                    await RunOnceAsync(stoppingToken);
                }
                catch (Exception ex) when (ex is not OperationCanceledException)
                {
                    // One bad pass must not stop every later one.
                    _logger.LogError(ex, "Reminder pass failed.");
                }
            }
            while (await WaitAsync(timer, stoppingToken));
        }

        private static async Task<bool> WaitAsync(PeriodicTimer timer, CancellationToken ct)
        {
            try { return await timer.WaitForNextTickAsync(ct); }
            catch (OperationCanceledException) { return false; }
        }

        private async Task RunOnceAsync(CancellationToken ct)
        {
            using var scope = _scopes.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            var notifications = scope.ServiceProvider.GetRequiredService<INotificationService>();
            var now = DateTime.UtcNow;

            await RemindDueTomorrowAsync(db, notifications, now, ct);
            await NoticeOverdueAsync(db, notifications, now, ct);
            await NoticeSuspensionStartedAsync(db, notifications, now, ct);
            await NoticeAccessRestoredAsync(db, notifications, now, ct);
            await RemindExpiringDocumentsAsync(db, notifications, now, ct);
            await PruneDeviceTokensAsync(db, now, ct);
        }

        /// <summary>How many days before a licence or registration runs out the user is told.</summary>
        private const int ExpiryWarningDays = 30;

        /// <summary>
        /// A licence or registration that is about to run out, or just did.
        /// </summary>
        /// <remarks>
        /// Each notice records the expiry it was sent for, not when it was sent. A
        /// renewed document has a new expiry, so it is warned about in its turn
        /// without anything having to reset the stamp.
        ///
        /// The same <see cref="CatchUpWindow"/> applies as to an overdue bill: an
        /// account whose licence lapsed months ago, before this existed, is not
        /// sent a notice for it on the first pass after deploying.
        /// </remarks>
        private static async Task RemindExpiringDocumentsAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            var horizon = now.Date.AddDays(ExpiryWarningDays);
            var floor = now - CatchUpWindow;

            var users = await db.Set<User>()
                .Where(u => u.Role == UserRole.User
                         && u.AccountStatus == AccountStatus.Active
                         && !u.IsDeleted
                         && u.LicenseValidThrough != null
                         && u.LicenseValidThrough <= horizon
                         && u.LicenseValidThrough > floor
                         && u.LicenseExpiryReminderSentFor != u.LicenseValidThrough)
                .ToListAsync(ct);

            foreach (var user in users)
            {
                var expiry = user.LicenseValidThrough!.Value;
                user.LicenseExpiryReminderSentFor = expiry;
                await db.SaveChangesAsync(ct);

                await notifications.NotifyUserAsync(
                    user.Id,
                    NotificationType.Reminder,
                    ExpiryTitle("licence", expiry, now),
                    ExpiryBody("licence", expiry, now),
                    new Dictionary<string, string> { ["screen"] = "profile" },
                    ct);
            }

            // E-bikes have no registration, so there is nothing of theirs to warn about.
            var vehicles = await db.Set<Vehicle>()
                .Include(v => v.User)
                .Where(v => !v.IsEBike
                         && v.User.Role == UserRole.User
                         && v.User.AccountStatus == AccountStatus.Active
                         && !v.User.IsDeleted
                         && v.RegistrationValidThrough != null
                         && v.RegistrationValidThrough <= horizon
                         && v.RegistrationValidThrough > floor
                         && v.RegistrationExpiryReminderSentFor != v.RegistrationValidThrough)
                .ToListAsync(ct);

            foreach (var vehicle in vehicles)
            {
                var expiry = vehicle.RegistrationValidThrough!.Value;
                vehicle.RegistrationExpiryReminderSentFor = expiry;
                await db.SaveChangesAsync(ct);

                var what = $"registration for {vehicle.PlateNumber}";
                await notifications.NotifyUserAsync(
                    vehicle.UserId,
                    NotificationType.Reminder,
                    ExpiryTitle(what, expiry, now),
                    ExpiryBody(what, expiry, now),
                    new Dictionary<string, string> { ["screen"] = "profile" },
                    ct);
            }
        }

        private static int DaysLeft(DateTime expiry, DateTime now) => (expiry.Date - now.Date).Days;

        private static string ExpiryTitle(string what, DateTime expiry, DateTime now)
        {
            var days = DaysLeft(expiry, now);
            return days < 0
                ? $"Your {what} has expired"
                : days == 0
                    ? $"Your {what} expires today"
                    : $"Your {what} expires in {days} {(days == 1 ? "day" : "days")}";
        }

        private static string ExpiryBody(string what, DateTime expiry, DateTime now) =>
            DaysLeft(expiry, now) < 0
                ? $"Renew your {what} and upload the new one in the app to keep using the gate."
                : $"Renew your {what} and upload the new one in the app before {expiry:MMMM d}.";

        private static IQueryable<PaymentTransaction> Unpaid(AppDbContext db) =>
            db.Set<PaymentTransaction>()
                .Where(p => (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing)
                         && p.PaidAt == null
                         && p.AmountDue > 0m
                         && p.DueAt != null
                         && !p.User.IsDeleted);

        private static async Task RemindDueTomorrowAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            // Only bills that have been around a while: one created a few hours
            // before its deadline already told the payer everything when it was
            // raised.
            var bills = await Unpaid(db)
                .Where(p => p.DueReminderSentAt == null
                         && p.DueAt > now
                         && p.DueAt <= now.AddDays(1)
                         && p.CreatedAt <= now.AddDays(-1))
                .ToListAsync(ct);

            foreach (var bill in bills)
            {
                bill.DueReminderSentAt = now;
                await db.SaveChangesAsync(ct);

                await notifications.NotifyUserAsync(
                    bill.UserId,
                    NotificationType.Reminder,
                    "Payment due tomorrow",
                    $"{Describe(bill)} of ₱{bill.AmountDue:0.00} is due tomorrow. Pay in the app to stay in good standing.",
                    new Dictionary<string, string> { ["paymentId"] = bill.Id.ToString() },
                    ct);
            }
        }

        private static async Task NoticeOverdueAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            var bills = await Unpaid(db)
                .Where(p => p.OverdueNoticeSentAt == null
                         && p.DueAt <= now
                         && p.DueAt > now - CatchUpWindow)
                .ToListAsync(ct);

            foreach (var bill in bills)
            {
                bill.OverdueNoticeSentAt = now;
                await db.SaveChangesAsync(ct);

                await notifications.NotifyUserAsync(
                    bill.UserId,
                    NotificationType.Reminder,
                    "Payment overdue",
                    $"{Describe(bill)} of ₱{bill.AmountDue:0.00} is past its due date. Please settle it in the app.",
                    new Dictionary<string, string> { ["paymentId"] = bill.Id.ToString() },
                    ct);
            }
        }

        private static async Task NoticeSuspensionStartedAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            // Scheduled suspensions only. One already in force when it was
            // issued (RfidSuspendedFrom null) was announced by the violation
            // push itself.
            var users = await db.Set<User>()
                .Where(u => !u.IsDeleted
                         && u.RfidStatus == RfidStatus.Suspended
                         && u.RfidSuspendedFrom != null
                         && u.RfidSuspendedFrom <= now
                         && u.RfidSuspendedFrom > now - CatchUpWindow
                         && (u.SuspensionNoticeSentFor == null || u.SuspensionNoticeSentFor != u.RfidSuspendedFrom))
                .ToListAsync(ct);

            foreach (var user in users)
            {
                // Lifted or expired between issue and start: nothing to announce.
                if (!RfidAccess.IsSuspendedNow(user, now)) continue;

                user.SuspensionNoticeSentFor = user.RfidSuspendedFrom;
                await db.SaveChangesAsync(ct);

                var until = user.RfidSuspendedUntil is DateTime end
                    ? $" until {end:MMM d}"
                    : " until further notice";

                await notifications.NotifyUserAsync(
                    user.Id,
                    NotificationType.Reminder,
                    "Your suspension has started",
                    $"Your RFID card will not open the gate{until}. Open the app to see why.",
                    new Dictionary<string, string> { ["screen"] = "violations" },
                    ct);
            }
        }

        private static async Task NoticeAccessRestoredAsync(
            AppDbContext db, INotificationService notifications, DateTime now, CancellationToken ct)
        {
            // A temporary suspension that has run out. The gate reactivates it
            // lazily on the next tap; doing it here as well means the person
            // finds out before they drive in, not at the barrier.
            var users = await db.Set<User>()
                .Where(u => !u.IsDeleted
                         && u.RfidStatus == RfidStatus.Suspended
                         && u.RfidSuspendedUntil != null
                         && u.RfidSuspendedUntil <= now)
                .ToListAsync(ct);

            foreach (var user in users)
            {
                // Reactivated either way, but a suspension that ended weeks ago
                // and was never tidied up is not news worth a buzz.
                var recent = user.RfidSuspendedUntil > now - CatchUpWindow;

                RfidAccess.Reactivate(user, now);
                await db.SaveChangesAsync(ct);

                if (!recent) continue;

                await notifications.NotifyUserAsync(
                    user.Id,
                    NotificationType.Reminder,
                    "Your access is back",
                    "Your suspension has ended. Your RFID card opens the gate again.",
                    null,
                    ct);
            }
        }

        private async Task PruneDeviceTokensAsync(AppDbContext db, DateTime now, CancellationToken ct)
        {
            // Splash re-registers every launch, which refreshes LastSeenAt, so
            // only phones that stopped opening the app entirely are removed.
            var removed = await db.Set<DeviceToken>()
                .Where(t => t.LastSeenAt < now - DeviceTokenLifetime)
                .ExecuteDeleteAsync(ct);

            if (removed > 0)
                _logger.LogInformation("Removed {Count} device token(s) unseen for 60 days.", removed);
        }

        private static string Describe(PaymentTransaction bill) =>
            bill.Source == PaymentSource.ParkingFee ? "Your parking fee" : "Your violation penalty";
    }
}
