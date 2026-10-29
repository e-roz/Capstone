using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>What just landed in an administrator's queue.</summary>
    public enum StaffAlertKind
    {
        Registration,
        Renewal,
        Appeal,
        Incident,

        /// <summary>A driver keeps leaving without confirming their bay: a possible strike to review.</summary>
        UnconfirmedParking
    }

    /// <summary>
    /// Tells the administrators that something is waiting for them.
    /// </summary>
    /// <remarks>
    /// The queues were always there, but nothing ever said a new item had arrived:
    /// an administrator found out by opening the page. This writes a notification
    /// addressed to the Admin role, which the panel's bell and inbox show, and
    /// carries the page to open in its data.
    ///
    /// Best-effort and never throws, for the same reason a user's notification
    /// does not: the applicant's submission has already succeeded, and failing it
    /// because the heads-up could not be written would lose their work.
    /// </remarks>
    public interface IStaffAlerts
    {
        Task RaiseAsync(StaffAlertKind kind, Guid aboutUserId, CancellationToken ct);
    }

    public class StaffAlerts : IStaffAlerts
    {
        private readonly AppDbContext _db;
        private readonly IPushSender _push;
        private readonly ILogger<StaffAlerts> _logger;

        public StaffAlerts(AppDbContext db, IPushSender push, ILogger<StaffAlerts> logger)
        {
            _db = db;
            _push = push;
            _logger = logger;
        }

        public async Task RaiseAsync(StaffAlertKind kind, Guid aboutUserId, CancellationToken ct)
        {
            try
            {
                var name = await _db.Set<User>().AsNoTracking()
                    .Where(u => u.Id == aboutUserId)
                    .Select(u => u.FullName)
                    .FirstOrDefaultAsync(ct);
                var who = string.IsNullOrWhiteSpace(name) ? "A user" : name.Trim();

                var (type, title, message, route) = kind switch
                {
                    StaffAlertKind.Registration => (
                        NotificationType.Account,
                        "New registration to review",
                        $"{who} has submitted their documents and is waiting for approval.",
                        "/pending"),
                    StaffAlertKind.Renewal => (
                        NotificationType.Account,
                        "New renewal to review",
                        $"{who} has sent a renewed licence or registration for review.",
                        "/pending"),
                    StaffAlertKind.Appeal => (
                        NotificationType.Violation,
                        "New violation appeal",
                        $"{who} has appealed a violation.",
                        "/violations"),
                    StaffAlertKind.UnconfirmedParking => (
                        NotificationType.Violation,
                        "Possible strike to review",
                        $"{who} left without confirming their bay {SlotConfirmPolicy.ReviewAt} times in {SlotConfirmPolicy.Window.Days} days. Review their parking history and decide whether to issue a violation.",
                        $"/users/{aboutUserId}"),
                    _ => (
                        NotificationType.Incident,
                        "New incident report",
                        $"{who} has reported an incident.",
                        "/incidents")
                };

                var data = new Dictionary<string, string> { ["route"] = route, ["kind"] = kind.ToString(), ["userId"] = aboutUserId.ToString() };

                _db.Set<Notification>().Add(new Notification
                {
                    Id = Guid.NewGuid(),
                    Title = title,
                    Message = message,
                    Type = type,
                    TargetRole = UserRole.Admin,
                    TargetUserId = null,
                    CreatedByUserId = Guid.Empty, // raised by the system, not an admin
                    CreatedAt = DateTime.UtcNow,
                    Data = JsonSerializer.Serialize(data)
                });
                await _db.SaveChangesAsync(ct);

                await _push.SendToRoleAsync(UserRole.Admin, title, message,
                    new Dictionary<string, string> { ["type"] = "notification", ["route"] = route }, ct);
            }
            catch (Exception ex) when (ex is not OperationCanceledException)
            {
                _logger.LogError(ex, "Could not raise a {Kind} alert for the administrators.", kind);
            }
        }
    }
}
