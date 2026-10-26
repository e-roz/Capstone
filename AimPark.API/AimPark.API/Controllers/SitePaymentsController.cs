using System.Security.Claims;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// What a guard does about a driver held at the exit with a fee to pay: take
    /// cash, or let them out still owing.
    /// </summary>
    /// <remarks>
    /// Under <c>api/site</c> on purpose. The site server answers these itself, so a
    /// guard can take cash when the internet is down; <c>api/payments</c> is
    /// forwarded to the cloud and would fail exactly then. Both actions are
    /// written on the bill (see <see cref="ExitPayment"/>) and reach the cloud
    /// with it.
    ///
    /// Neither opens the barrier. The driver taps their card again, which is what
    /// opens it, so a gate is only ever opened by a tap that closes a session.
    /// </remarks>
    [ApiController]
    [Route("api/site/payments")]
    [Authorize(AuthenticationSchemes = JwtBearerDefaults.AuthenticationScheme, Roles = "Admin,Security")]
    public class SitePaymentsController : ControllerBase
    {
        private readonly AppDbContext _db;
        private readonly INotificationService _notifications;

        public SitePaymentsController(AppDbContext db, INotificationService notifications)
        {
            _db = db;
            _notifications = notifications;
        }

        public class ReleaseDto
        {
            public string? Reason { get; set; }
        }

        /// <summary>
        /// The guard has taken this bill's amount in cash. The amount is the
        /// bill's own and cannot be typed, so the record always matches what the
        /// driver was asked for.
        /// </summary>
        [HttpPost("{paymentId:guid}/cash")]
        public async Task<ActionResult<object>> ReceiveCash(Guid paymentId, CancellationToken ct)
        {
            var bill = await _db.Set<PaymentTransaction>().FirstOrDefaultAsync(p => p.Id == paymentId, ct);
            if (bill is null)
                return NotFound(new { message = "That bill was not found." });

            // A second press, or a second guard, must not take the money twice.
            if (bill.Status == PaymentStatus.Paid)
                return Ok(Receipt(bill, "Already paid."));

            if (bill.Status == PaymentStatus.Waived)
                return Conflict(new { message = "That bill was waived, so there is nothing to collect." });

            if (bill.AmountDue <= 0m)
                return Conflict(new { message = "There is nothing to collect on that bill." });

            var now = DateTime.UtcNow;
            var (from, to) = ExitPayment.DayRange(ExitPayment.ManilaDay(now));
            var takenToday = await _db.Set<PaymentTransaction>().CountAsync(p =>
                p.Method == PaymentMethod.Cash && p.PaidAt >= from && p.PaidAt < to, ct);

            bill.Status = PaymentStatus.Paid;
            bill.PaidAt = now;
            bill.Method = PaymentMethod.Cash;
            bill.Provider = ExitPayment.CashProvider;
            bill.ConfirmedByUserId = CurrentUserId();
            bill.ReferenceNumber = ExitPayment.CashReference(now, takenToday + 1);
            await _db.SaveChangesAsync(ct);

            await _notifications.NotifyUserAsync(
                bill.UserId,
                NotificationType.Payment,
                "Payment received",
                $"₱{bill.AmountDue:0.00} received in cash. Tap your card again to leave.",
                new Dictionary<string, string> { ["paymentId"] = bill.Id.ToString() },
                ct);

            return Ok(Receipt(bill, "Cash recorded."));
        }

        /// <summary>
        /// Lets the driver through on their next tap without paying. The bill stays
        /// unpaid, so they cannot enter again until it is settled. For a dead
        /// phone, a down connection or a car that must go.
        /// </summary>
        [HttpPost("{paymentId:guid}/release")]
        public async Task<ActionResult<object>> Release(
            Guid paymentId, [FromBody] ReleaseDto? dto, CancellationToken ct)
        {
            var bill = await _db.Set<PaymentTransaction>().FirstOrDefaultAsync(p => p.Id == paymentId, ct);
            if (bill is null)
                return NotFound(new { message = "That bill was not found." });

            if (bill.Status is PaymentStatus.Paid or PaymentStatus.Waived)
                return Ok(new { message = "That bill is already settled; the driver can leave." });

            var reason = (dto?.Reason ?? "").Trim();
            if (reason.Length == 0)
                return BadRequest(new { message = "Say why the driver is being let out." });

            // The bill stays Pending. The reason rides in the reference column so
            // it shows on the payment and reaches the cloud with it.
            bill.Provider = ExitPayment.ReleasedProvider;
            bill.ConfirmedByUserId = CurrentUserId();
            bill.ReferenceNumber = Truncate($"RELEASED: {reason}", 128);
            await _db.SaveChangesAsync(ct);

            return Ok(new { message = "The driver can tap their card to leave. The bill is still owed." });
        }

        /// <summary>
        /// Cash taken on one day (Manila time), for counting the drawer at the end of
        /// a shift. A guard sees their own total beside everyone's; an admin sees
        /// each guard.
        /// </summary>
        [HttpGet("cash-summary")]
        public async Task<ActionResult<object>> CashSummary([FromQuery] DateOnly? date, CancellationToken ct)
        {
            var day = date ?? ExitPayment.ManilaDay(DateTime.UtcNow);
            var (from, to) = ExitPayment.DayRange(day);

            var rows = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.Method == PaymentMethod.Cash && p.PaidAt >= from && p.PaidAt < to)
                .Select(p => new { p.ConfirmedByUserId, p.AmountDue })
                .ToListAsync(ct);

            var names = await _db.Set<User>().AsNoTracking()
                .Where(u => rows.Select(r => r.ConfirmedByUserId).Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.FullName, ct);

            var me = CurrentUserId();
            var byGuard = rows
                .GroupBy(r => r.ConfirmedByUserId)
                .Select(g => new
                {
                    guardId = g.Key,
                    guardName = g.Key is Guid id && names.TryGetValue(id, out var n) ? n : "Unknown",
                    count = g.Count(),
                    total = g.Sum(r => r.AmountDue)
                })
                .OrderByDescending(g => g.total)
                .ToList();

            return Ok(new
            {
                date = day.ToString("yyyy-MM-dd"),
                count = rows.Count,
                total = rows.Sum(r => r.AmountDue),
                mine = new
                {
                    count = rows.Count(r => r.ConfirmedByUserId == me),
                    total = rows.Where(r => r.ConfirmedByUserId == me).Sum(r => r.AmountDue)
                },
                byGuard
            });
        }

        private static object Receipt(PaymentTransaction bill, string message) => new
        {
            message,
            paymentId = bill.Id,
            amount = bill.AmountDue,
            referenceNumber = bill.ReferenceNumber,
            paidAt = bill.PaidAt
        };

        private static string Truncate(string text, int max)
            => text.Length <= max ? text : text[..max];

        private Guid? CurrentUserId()
            => Guid.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var id) ? id : null;
    }
}
