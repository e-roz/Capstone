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
    /// Set to a date after drivers have been told, so nobody is punished by surprise:
    /// sessions that began before it are never counted, and unset, nothing counts.
    /// </remarks>
    public class SlotConfirmPolicyOptions
    {
        public const string Section = "SlotConfirmPolicy";

        /// <summary>Sessions that began before this are never counted. Null turns the whole thing off.</summary>
        public DateTime? CountFrom { get; set; }
    }

    /// <summary>
    /// Warns a driver who leaves without confirming their bay, and issues a
    /// violation for each time after the warning.
    /// </summary>
    /// <remarks>
    /// Cloud only, like the confirms it counts. A bay can only be confirmed while
    /// the car is inside, so a session without a confirm is final the moment it
    /// ends. Within <see cref="SlotConfirmPolicy.Window"/> the first
    /// <see cref="SlotConfirmPolicy.Warnings"/> such sessions bring a warning and
    /// every later one a violation under the rule titled
    /// <see cref="SlotConfirmPolicy.RuleTitle"/>. The violation goes through the
    /// normal flow: the driver can appeal, and the fine is only raised if it
    /// stands. An admin can switch it off by deactivating that rule.
    ///
    /// Each session is handled once, recognised by the notification or violation
    /// it produced, so it needs no column of its own.
    /// </remarks>
    public class UnconfirmedParkingService : BackgroundService
    {
        private static readonly TimeSpan Interval = TimeSpan.FromMinutes(10);

        public const string WarningMarker = "\"kind\":\"UnconfirmedWarning\"";

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
                    var violations = scope.ServiceProvider.GetRequiredService<IViolationService>();
                    await RunAsync(db, notifications, violations, _options.Value, DateTime.UtcNow, stoppingToken);
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

        private sealed record Unconfirmed(Guid LogId, Guid UserId, DateTime EntryTime, DateTime ExitTime);

        /// <summary>
        /// Sessions that ended without a confirm and count, oldest exit first, in
        /// the window that is still held against the driver.
        /// </summary>
        private static async Task<List<Unconfirmed>> UnconfirmedAsync(
            AppDbContext db, SlotConfirmPolicyOptions options, DateTime now, CancellationToken ct)
        {
            if (options.CountFrom is not DateTime countFrom) return [];

            var countFromUtc = countFrom.ToUniversalTime();
            var windowStart = now - SlotConfirmPolicy.Window;
            var since = countFromUtc > windowStart ? countFromUtc : windowStart;

            var sessions = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId != null
                         && l.VisitorPassId == null
                         && l.ExitTime != null
                         && l.SlotConfirmedAt == null
                         && l.EntryTime >= since)
                .Select(l => new Unconfirmed(l.Id, l.UserId!.Value, l.EntryTime, l.ExitTime!.Value))
                .ToListAsync(ct);

            return sessions
                .Where(s => SlotConfirmPolicy.Counts(s.UserId, s.EntryTime, s.ExitTime))
                .OrderBy(s => s.ExitTime)
                .ToList();
        }

        /// <summary>Counted unconfirmed sessions per driver, as of <paramref name="now"/>.</summary>
        public static async Task<Dictionary<Guid, int>> CountAsync(
            AppDbContext db, SlotConfirmPolicyOptions options, DateTime now, CancellationToken ct)
            => (await UnconfirmedAsync(db, options, now, ct))
                .GroupBy(s => s.UserId)
                .ToDictionary(g => g.Key, g => g.Count());

        /// <summary>
        /// The policy rule behind the violation, created the first time it is needed so
        /// there is no setup step. Null when an admin has deactivated it: no violations.
        /// </summary>
        private static async Task<PolicyRule?> RuleAsync(AppDbContext db, CancellationToken ct)
        {
            var rule = await db.Set<PolicyRule>().FirstOrDefaultAsync(r => r.Title == SlotConfirmPolicy.RuleTitle, ct);
            if (rule is null)
            {
                rule = new PolicyRule
                {
                    Title = SlotConfirmPolicy.RuleTitle,
                    Description = "Leaving the lot without confirming in the app which bay you parked in. The first time in 30 days is a warning.",
                    Category = PolicyCategory.Parking,
                    DefaultPenaltyAmount = SlotConfirmPolicy.PenaltyAmount,
                    DefaultSuspensionType = SuspensionType.None,
                    AppealWindowDays = ViolationService.DefaultAppealWindowDays,
                    IsActive = true,
                };
                db.Add(rule);
                await db.SaveChangesAsync(ct);
            }

            return rule.IsActive ? rule : null;
        }

        /// <summary>One pass. Returns how many warnings and violations it sent.</summary>
        public static async Task<(int Warned, int Violated)> RunAsync(
            AppDbContext db, INotificationService notifications, IViolationService violations,
            SlotConfirmPolicyOptions options, DateTime now, CancellationToken ct)
        {
            var sessions = await UnconfirmedAsync(db, options, now, ct);
            if (sessions.Count == 0) return (0, 0);

            var warned = 0;
            var violated = 0;
            PolicyRule? rule = null;
            var ruleLoaded = false;
            Guid? issuer = null;

            foreach (var driver in sessions.GroupBy(s => s.UserId))
            {
                var nth = 0;
                foreach (var s in driver)
                {
                    nth++;

                    if (nth <= SlotConfirmPolicy.Warnings)
                    {
                        var logMarker = $"\"logId\":\"{s.LogId}\"";
                        var alreadyWarned = await db.Set<Notification>().AsNoTracking().AnyAsync(n =>
                            n.TargetUserId == s.UserId
                            && n.Data != null
                            && n.Data.Contains(WarningMarker)
                            && n.Data.Contains(logMarker), ct);
                        if (alreadyWarned) continue;

                        await notifications.NotifyUserAsync(
                            s.UserId,
                            NotificationType.Reminder,
                            "Confirm your bay each time you park",
                            "You left without confirming your bay. This is a warning. " +
                            $"Next time you leave without confirming, it is a violation with a ₱{SlotConfirmPolicy.PenaltyAmount:0} penalty. " +
                            "Confirm in the app before you drive out.",
                            new Dictionary<string, string>
                            {
                                ["screen"] = "parking-slots",
                                ["kind"] = "UnconfirmedWarning",
                                ["logId"] = s.LogId.ToString(),
                            },
                            ct);
                        warned++;
                        continue;
                    }

                    if (!ruleLoaded)
                    {
                        rule = await RuleAsync(db, ct);
                        ruleLoaded = true;
                        // A violation needs someone to issue it. The earliest admin account stands in.
                        issuer = await db.Set<User>().AsNoTracking()
                            .Where(u => u.Role == UserRole.Admin && !u.IsDeleted)
                            .OrderBy(u => u.CreatedAt)
                            .Select(u => (Guid?)u.Id)
                            .FirstOrDefaultAsync(ct);
                    }
                    if (rule is null || issuer is null) continue;

                    var alreadyIssued = await db.Set<Violation>().AsNoTracking()
                        .AnyAsync(v => v.ParkingLogId == s.LogId && v.PolicyRuleId == rule.Id, ct);
                    if (alreadyIssued) continue;

                    var result = await violations.IssueAsync(new DTOs.IssueViolationDto
                    {
                        UserId = s.UserId,
                        PolicyRuleId = rule.Id,
                        ParkingLogId = s.LogId,
                        Description = $"Left the lot on {s.ExitTime.AddHours(8):MMM d, yyyy h:mm tt} without confirming the bay. " +
                                      "Issued automatically after the warning.",
                    }, issuer.Value, ct);

                    if (result.Result is Microsoft.AspNetCore.Mvc.OkObjectResult)
                        violated++;
                }
            }

            return (warned, violated);
        }
    }
}
