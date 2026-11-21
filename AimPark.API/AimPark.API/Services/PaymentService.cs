using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace AimPark.API.Services
{
    public class PaymentService : IPaymentService
    {
        // No bill has a due date. A parking fee is owed the moment the driver
        // leaves, and a violation fine exists only once the violation is final;
        // either one stops the next entry at the gate until it is paid. A date
        // weeks out told the payer the opposite of what the gate did.

        private readonly IRepository<PaymentTransaction> _payments;
        private readonly IRepository<ParkingRate> _rates;
        private readonly INotificationService _notificationService;
        private readonly AppDbContext _db;
        private readonly IPaymentGateway _gateway;
        private readonly ILogger<PaymentService> _logger;

        /// <summary>How long the meter pauses after a parking bill is paid.</summary>
        private readonly TimeSpan _grace;
        private readonly double _graceMinutes;

        public PaymentService(
            IRepository<PaymentTransaction> payments,
            IRepository<ParkingRate> rates,
            INotificationService notificationService,
            AppDbContext db,
            IPaymentGateway gateway,
            ILogger<PaymentService> logger,
            IOptions<GateOptions>? gate = null)
        {
            _payments = payments;
            _rates = rates;
            _notificationService = notificationService;
            _db = db;
            _gateway = gateway;
            _logger = logger;
            _grace = TimeSpan.FromMinutes(gate?.Value.PaidExitGraceMinutes ?? new GateOptions().PaidExitGraceMinutes);
            _graceMinutes = _grace.TotalMinutes;
        }

        public async Task<BillResult?> BillOwedAsync(ParkingLog log, VisitPrice price, bool paidAhead, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");
            if (price.OwedNow <= 0m)
                return null;

            var settledIds = price.SettledBills.Select(b => b.Id).ToHashSet();
            var open = (await _db.Set<PaymentTransaction>()
                    .Where(p => p.ParkingLogId == log.Id
                        && (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing))
                    .OrderByDescending(p => p.CreatedAt)
                    .ToListAsync(ct))
                .Where(p => !settledIds.Contains(p.Id) && !ExitPayment.IsReleased(p))
                .ToList();

            // A checkout already open carries its own amount; only time past it
            // goes on a bill of its own.
            var inFlight = open.Where(p => p.Status == PaymentStatus.Processing).ToList();
            var toBill = price.OwedNow - inFlight.Sum(p => p.AmountDue);
            if (toBill <= 0m)
                return new BillResult(inFlight[0], false, inFlight[0].PaidAhead);

            var coversFrom = inFlight.Count > 0
                ? inFlight.Max(p => p.CoversTo ?? p.CreatedAt)
                : price.UnpaidFrom;
            // A bill paid inside the first hour covers the whole first hour.
            var coversTo = price.At < price.Breakdown.FirstHourEndsAt ? price.Breakdown.FirstHourEndsAt : price.At;
            var minutes = price.Breakdown.ChargeableMinutesBetween(coversFrom, coversTo);

            var pending = open.FirstOrDefault(p => p.Status == PaymentStatus.Pending);
            if (pending is not null)
            {
                var wasAhead = pending.PaidAhead;
                pending.AmountDue = toBill;
                pending.DurationMinutes = minutes;
                pending.RatePerHourApplied = price.RatePerHour;
                pending.CoversFrom = coversFrom;
                pending.CoversTo = coversTo;
                // Once the gate has held a driver for it, it stays a gate bill.
                pending.PaidAhead = pending.PaidAhead && paidAhead;
                await _db.SaveChangesAsync(ct);
                return new BillResult(pending, false, wasAhead);
            }

            var bill = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = minutes,
                RatePerHourApplied = price.RatePerHour,
                AmountDue = toBill,
                CoversFrom = coversFrom,
                CoversTo = coversTo,
                Status = PaymentStatus.Pending,
                PaidAhead = paidAhead,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };
            await _payments.AddAsync(bill, ct);
            await _payments.SaveAsync(ct);
            return new BillResult(bill, true, false);
        }

        // Called by ParkingHistoryService.LogExitAsync right after ExitTime is recorded.
        public Task<ParkingFeeQuote> QuoteForCompletedLogAsync(ParkingLog log, CancellationToken ct)
            => QuoteAsync(log, log.ExitTime!.Value, ct);

        // The latest one: a session that ran past its paid-ahead window has a
        // second bill, and that is the one the gate is waiting on.
        public Task<PaymentTransaction?> FindForLogAsync(Guid parkingLogId, CancellationToken ct)
            => _db.Set<PaymentTransaction>()
                .Where(p => p.ParkingLogId == parkingLogId)
                .OrderByDescending(p => p.CreatedAt)
                .FirstOrDefaultAsync(ct);

        public async Task<ParkingFeeQuote> QuoteAsync(ParkingLog log, DateTime at, CancellationToken ct)
        {
            var (ratePerHour, minimum) = await RateForAsync(log, ct);
            var durationMinutes = ParkingFeeMath.ChargedMinutes(log.EntryTime, at);
            var amountDue = ParkingFeeMath.Price(ratePerHour, minimum, durationMinutes);
            return new ParkingFeeQuote(durationMinutes, ratePerHour, amountDue);
        }

        public async Task<(decimal RatePerHour, decimal MinimumFee)> RateForAsync(ParkingLog log, CancellationToken ct)
        {
            // The visit records what drove in. The bay is only a fallback for old
            // visits without it; a car that never confirmed a bay has no bay to ask.
            VehicleType? vehicleType = log.VehicleType;
            if (vehicleType is null && log.SlotId is not null)
            {
                vehicleType = await _db.Set<ParkingSlot>().AsNoTracking()
                    .Where(s => s.Id == log.SlotId)
                    .Select(s => s.VehicleType)
                    .FirstOrDefaultAsync(ct);
            }

            var rate = await _db.Set<ParkingRate>().AsNoTracking()
                .FirstOrDefaultAsync(r => r.VehicleType == vehicleType, ct);

            if (rate is null && vehicleType is not null)
            {
                // No rate configured for this specific vehicle type — fall back to the default rate.
                rate = await _db.Set<ParkingRate>().AsNoTracking()
                    .FirstOrDefaultAsync(r => r.VehicleType == null, ct);
            }

            if (rate is null)
            {
                // No rate set: the session costs nothing, and has no minimum either.
                // The arithmetic, and why it rounds minutes up and has a floor, is
                // in ParkingFeeMath.
                return (0m, 0m);
            }

            // The rate is locked at entry: a car that was already inside when the
            // rate changed pays what it was when it came in.
            if (log.EntryTime < rate.UpdatedAt && rate.PreviousRatePerHour is decimal previous)
                return (previous, rate.PreviousMinimumFee ?? rate.MinimumFee);

            return (rate.RatePerHour, rate.MinimumFee);
        }

        public async Task<PaymentTransaction> CreateForCompletedLogAsync(ParkingLog log, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException(
                    "A visitor session has no account to bill. Use QuoteForCompletedLogAsync.");

            // Already raised at the exit gate, where the driver was asked to pay
            // before the barrier would open. Nothing more to create.
            var raised = await FindForLogAsync(log.Id, ct);
            if (raised is not null)
                return raised;

            var (durationMinutes, ratePerHour, amountDue) =
                await QuoteForCompletedLogAsync(log, ct);

            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = durationMinutes,
                RatePerHourApplied = ratePerHour,
                AmountDue = amountDue,
                Status = PaymentStatus.Pending,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            // The driver has just left; telling them what they owe now is the
            // difference between a fee they act on and one they discover later.
            var hours = durationMinutes / 60;
            var minutes = durationMinutes % 60;
            var duration = hours > 0 ? $"{hours}h {minutes}m" : $"{minutes}m";

            // A free session is still worth a receipt, but "Amount due: ₱0.00"
            // under a "Parking fee" title reads like a bill.
            if (amountDue > 0m)
            {
                await _notificationService.NotifyUserAsync(
                    log.UserId.Value,
                    NotificationType.Payment,
                    "Parking fee",
                    $"You parked for {duration}. Amount due: ₱{amountDue:0.00}.",
                    new Dictionary<string, string> { ["paymentId"] = transaction.Id.ToString() },
                    ct);
            }
            else
            {
                await _notificationService.NotifyUserAsync(
                    log.UserId.Value,
                    NotificationType.Parking,
                    "You've left",
                    $"You parked for {duration}. Nothing to pay.",
                    new Dictionary<string, string> { ["screen"] = "parking-history" },
                    ct);
            }

            return transaction;
        }

        public async Task<PaymentTransaction> RaiseExitBillAsync(ParkingLog log, DateTime at, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");

            var existing = await FindForLogAsync(log.Id, ct);
            if (existing is not null)
                return existing;

            var (durationMinutes, ratePerHour, amountDue) = await QuoteAsync(log, at, ct);

            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = durationMinutes,
                RatePerHourApplied = ratePerHour,
                AmountDue = amountDue,
                Status = PaymentStatus.Pending,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            await _notificationService.NotifyUserAsync(
                log.UserId.Value,
                NotificationType.Payment,
                "Pay to leave",
                $"Your parking fee is ₱{amountDue:0.00}. Pay in the app or at the guard post, then tap your card again.",
                new Dictionary<string, string> { ["paymentId"] = transaction.Id.ToString() },
                ct);

            return transaction;
        }

        public async Task<PaymentTransaction?> RaiseAheadAsync(ParkingLog log, DateTime at, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");

            var existing = await FindForLogAsync(log.Id, ct);

            // Already paid, already being paid, or already held at the gate: that
            // bill is the one to pay, as it stands.
            if (existing is not null
                && !(existing.PaidAhead && existing.Status == PaymentStatus.Pending))
                return existing;

            // A paid-ahead bill nobody paid yet is priced again, so a driver who
            // asked an hour ago and pays now pays for that hour too. Only for the
            // rest of the stay, though: it may be the second bill on a session
            // whose first was paid already.
            if (existing is not null)
            {
                await RepriceOpenBillAsync(existing, log, at, ct);
                _payments.Update(existing);
                await _payments.SaveAsync(ct);
                return existing;
            }

            var (durationMinutes, ratePerHour, amountDue) = await QuoteAsync(log, at, ct);
            if (amountDue <= 0m)
                return null;

            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = durationMinutes,
                RatePerHourApplied = ratePerHour,
                AmountDue = amountDue,
                Status = PaymentStatus.Pending,
                PaidAhead = true,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };

            // No notice: the driver asked for this in the app and is looking at it.
            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);
            return transaction;
        }

        public async Task RepriceOpenBillAsync(PaymentTransaction bill, ParkingLog log, DateTime at, CancellationToken ct)
        {
            var (durationMinutes, ratePerHour, amountDue) = await QuoteAsync(log, at, ct);

            // Settled the same way the live fee counts it (Paid or Waived), so the
            // bill matches the "still to pay" the app showed.
            var settled = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.ParkingLogId == log.Id && p.Id != bill.Id
                    && (p.Status == PaymentStatus.Paid || p.Status == PaymentStatus.Waived))
                .Select(p => new { p.AmountDue, p.DurationMinutes })
                .ToListAsync(ct);

            bill.DurationMinutes = Math.Max(0, durationMinutes - settled.Sum(p => p.DurationMinutes));
            bill.RatePerHourApplied = ratePerHour;
            bill.AmountDue = Math.Max(0m, amountDue - settled.Sum(p => p.AmountDue));
        }

        public async Task<PaymentTransaction?> RaiseOverstayBillAsync(
            ParkingLog log, DateTime at, bool paidAhead, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException("A visitor session has no account to bill.");

            var (durationMinutes, ratePerHour, amountDue) = await QuoteAsync(log, at, ct);

            // What the whole stay costs now, less what the session was billed
            // already. Waived bills count as covered: someone decided that time
            // was not to be charged.
            var bills = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.ParkingLogId == log.Id)
                .ToListAsync(ct);
            var extra = amountDue - bills.Sum(b => b.AmountDue);
            if (extra <= 0m)
                return null;

            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId.Value,
                DurationMinutes = Math.Max(0, durationMinutes - bills.Sum(b => b.DurationMinutes)),
                RatePerHourApplied = ratePerHour,
                AmountDue = extra,
                Status = PaymentStatus.Pending,
                PaidAhead = paidAhead,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            // Asked for in the app, the driver is looking at it already.
            if (paidAhead)
                return transaction;

            await _notificationService.NotifyUserAsync(
                log.UserId.Value,
                NotificationType.Payment,
                "Pay to leave",
                $"You stayed past the time you paid for. The extra is ₱{extra:0.00}. Pay in the app or at the guard post, then tap your card again.",
                new Dictionary<string, string> { ["paymentId"] = transaction.Id.ToString() },
                ct);

            return transaction;
        }

        // Called by ViolationService.IssueAsync right after a violation is created.
        public async Task<PaymentTransaction> CreateForViolationAsync(Violation violation, CancellationToken ct)
        {
            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ViolationPenalty,
                ViolationId = violation.Id,
                UserId = violation.UserId,
                DurationMinutes = 0,
                RatePerHourApplied = 0,
                AmountDue = violation.PenaltyAmount,
                Status = PaymentStatus.Pending,
                DueAt = null,
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            return transaction;
        }

        // Called by ViolationService when an appeal is accepted or a violation dismissed.
        // Normally a no-op now that the fine is only raised on Accountable; it
        // still cleans up a fine raised under the old process.
        public async Task WaiveForViolationAsync(Guid violationId, CancellationToken ct)
        {
            var payment = await _payments.FindAsync(p => p.ViolationId == violationId, ct);

            // Paid and Waived are settled and must not be rewritten. Processing
            // is not settled — it is a checkout somebody opened — and an
            // appeal that succeeds while that window is up must still cancel the
            // fine, or the approval quietly fails to reach the money.
            if (payment is null
                || payment.Status is not (PaymentStatus.Pending or PaymentStatus.Processing))
                return;

            payment.Status = PaymentStatus.Waived;
            _payments.Update(payment);
            await _payments.SaveAsync(ct);
        }

        // Called when a user's account is revoked. Losing the account is the
        // penalty, so any violation fine still open is dropped rather than left
        // as a debt nobody can pay. Paid and Waived stay as they are.
        public async Task WaiveOpenPenaltiesForUserAsync(Guid userId, CancellationToken ct)
        {
            var open = await _db.Set<PaymentTransaction>()
                .Where(p => p.UserId == userId
                    && p.Source == PaymentSource.ViolationPenalty
                    && (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing))
                .ToListAsync(ct);

            if (open.Count == 0)
                return;

            foreach (var payment in open)
                payment.Status = PaymentStatus.Waived;

            await _db.SaveChangesAsync(ct);
        }

        // GET /api/payments
        public Task<ActionResult<PaymentListResponse>> GetMyPaymentsAsync(Guid userId, int page, int pageSize, CancellationToken ct)
            => ListAsync(_db.Set<PaymentTransaction>().AsNoTracking().Where(p => p.UserId == userId), page, pageSize, ct);

        // GET /api/payments/{id}
        public async Task<ActionResult<PaymentResponse>> GetMyPaymentDetailAsync(Guid userId, Guid paymentId, CancellationToken ct)
        {
            var response = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.Id == paymentId && p.UserId == userId)
                .Select(ToResponse())
                .FirstOrDefaultAsync(ct);

            if (response is null)
                return new NotFoundObjectResult(new { message = "Payment not found." });

            return new OkObjectResult(response);
        }

        // POST /api/payments/{id}/pay — mock cashless-payment stand-in
        // POST /api/payments/{paymentId}/checkout
        public async Task<ActionResult<CheckoutResponse>> StartCheckoutAsync(
            Guid userId,
            Guid paymentId,
            CancellationToken ct)
        {
            var payment = await _payments.FindAsync(p => p.Id == paymentId && p.UserId == userId, ct);
            if (payment is null)
                return new NotFoundObjectResult(new { message = "Payment not found." });

            if (payment.Status == PaymentStatus.Paid)
                return new BadRequestObjectResult(new { message = "This bill has already been paid." });

            if (payment.Status == PaymentStatus.Waived)
                return new BadRequestObjectResult(new { message = "This bill was waived. There is nothing to pay." });

            // Processing is allowed through, and on purpose. Someone who opened
            // the checkout and closed it without paying is left holding a bill
            // they cannot retry, and the alternative — waiting for the old
            // checkout to expire — is a locked screen with no explanation. A
            // fresh checkout replaces the abandoned one; only one of them can
            // ever be settled, because settlement is matched on the id.
            if (payment.AmountDue <= 0m)
                return new BadRequestObjectResult(new { message = "There is nothing to pay on this bill." });

            var description = payment.Source == PaymentSource.ParkingFee
                ? "AimPark parking fee"
                : "AimPark violation penalty";

            GatewayCheckout checkout;
            try
            {
                checkout = await _gateway.CreateCheckoutAsync(payment, description, ct);
            }
            catch (Exception ex)
            {
                // The bill is untouched, so the only thing lost is this attempt.
                _logger.LogError(ex, "Could not open a checkout for payment {PaymentId}.", paymentId);
                return new ObjectResult(new
                {
                    message = "The payment service could not be reached. Please try again in a moment."
                })
                { StatusCode = StatusCodes.Status502BadGateway };
            }

            payment.Status = PaymentStatus.Processing;
            payment.Provider = _gateway.Name;
            payment.ProviderPaymentId = checkout.ProviderPaymentId;
            payment.CheckoutStartedAt = DateTime.UtcNow;

            _payments.Update(payment);
            await _payments.SaveAsync(ct);

            return new OkObjectResult(new CheckoutResponse
            {
                PaymentId = payment.Id,
                CheckoutUrl = checkout.CheckoutUrl,
                Provider = _gateway.Name,
                AmountDue = payment.AmountDue
            });
        }

        // POST /api/payments/checkout-all — "Pay all"
        //
        // The server decides which bills those are and what they total; the phone
        // sends neither a list nor an amount. Payable means Pending, owing money,
        // and not already inside a checkout. They all get the same provider id, so
        // the one settlement that comes back pays every one of them.
        public async Task<ActionResult<CheckoutResponse>> StartCheckoutAllAsync(
            Guid userId,
            CancellationToken ct)
        {
            var bills = (await _payments.GetAllAsync(
                    p => p.UserId == userId
                      && p.Status == PaymentStatus.Pending
                      && p.PaidAt == null
                      && p.AmountDue > 0m,
                    ct))
                .OrderBy(p => p.CreatedAt)
                .ToList();

            if (bills.Count == 0)
            {
                // Also what a second tap gets while a Pay all is open: those bills
                // are Processing now, and a provider link cannot be rebuilt later.
                return new ConflictObjectResult(new
                {
                    message = "There is nothing to pay right now, or a payment is already in progress."
                });
            }

            GatewayCheckout checkout;
            try
            {
                checkout = await _gateway.CreateBundleCheckoutAsync(bills, ct);
            }
            catch (Exception ex)
            {
                // Nothing was touched, so the only thing lost is this attempt.
                _logger.LogError(ex, "Could not open a checkout for {Count} bills of user {UserId}.", bills.Count, userId);
                return new ObjectResult(new
                {
                    message = "The payment service could not be reached. Please try again in a moment."
                })
                { StatusCode = StatusCodes.Status502BadGateway };
            }

            var now = DateTime.UtcNow;
            foreach (var bill in bills)
            {
                bill.Status = PaymentStatus.Processing;
                bill.Provider = _gateway.Name;
                bill.ProviderPaymentId = checkout.ProviderPaymentId;
                bill.CheckoutStartedAt = now;
                _payments.Update(bill);
            }
            await _payments.SaveAsync(ct);

            return new OkObjectResult(new CheckoutResponse
            {
                PaymentId = bills[0].Id,
                PaymentIds = bills.Select(b => b.Id).ToList(),
                CheckoutUrl = checkout.CheckoutUrl,
                Provider = _gateway.Name,
                AmountDue = bills.Sum(b => b.AmountDue)
            });
        }

        // POST /api/payments/callback  (the provider calls this, not the app)
        public async Task<bool> HandleGatewayCallbackAsync(
            string rawBody,
            IDictionary<string, string> headers,
            CancellationToken ct)
        {
            if (!_gateway.TryReadEvent(rawBody, headers, out var settlement)) return false;

            // A real message about something other than money arriving. Nothing
            // to act on, and nothing wrong with it — answering "refused" would
            // only make the provider send it again.
            if (!settlement.Paid) return true;

            // One id can cover several bills ("Pay all"); a single bill is just the
            // case of one.
            var checkoutBills = await _payments.GetAllAsync(
                p => p.ProviderPaymentId == settlement.ProviderPaymentId, ct);

            if (checkoutBills.Count == 0)
            {
                // Not an error worth failing the callback over: a provider that
                // gets a non-2xx keeps retrying, and no number of retries will
                // conjure up a row. Logged, because it means an id was lost.
                _logger.LogWarning(
                    "Settlement for unknown checkout {CheckoutId}.",
                    settlement.ProviderPaymentId);
                return true;
            }

            // Providers retry until they get a 2xx, so the same settlement
            // arrives more than once as a matter of course. Paying attention to
            // it twice would move PaidAt and fire a second receipt at someone
            // who paid once.
            var open = checkoutBills.Where(b => b.Status != PaymentStatus.Paid).ToList();
            if (open.Count == 0) return true;

            var paidAt = DateTime.UtcNow;
            foreach (var bill in open)
            {
                bill.Status = PaymentStatus.Paid;
                bill.PaidAt = paidAt;
                bill.Method = settlement.Method ?? PaymentMethod.GCash;
                bill.ReferenceNumber = settlement.ReferenceNumber;
                bill.Provider ??= _gateway.Name;
                _payments.Update(bill);
            }
            await _payments.SaveAsync(ct);

            // One message for one payment, however many bills it covered.
            var first = open[0];
            var total = open.Sum(b => b.AmountDue);
            await _notificationService.NotifyUserAsync(
                first.UserId,
                NotificationType.Payment,
                "Payment received",
                open.Count == 1
                    ? $"₱{total:0.00} paid. Thank you."
                    : $"₱{total:0.00} paid for {open.Count} bills. Thank you.",
                new Dictionary<string, string> { ["paymentId"] = first.Id.ToString() },
                ct);

            return true;
        }

        // GET /api/admin/payments
        public Task<ActionResult<PaymentListResponse>> ListAllAsync(
            string? status, DateTime? from, DateTime? to, int page, int pageSize, CancellationToken ct)
        {
            var query = ApplyFilters(_db.Set<PaymentTransaction>().AsNoTracking(), status, from, to);
            return ListAsync(query, page, pageSize, ct);
        }

        /// <summary>Caps how much a single export can hand back.</summary>
        /// <remarks>
        /// Not streaming — a plain capped query. Fine at the scale of one
        /// campus lot; a deployment large enough to hit this would need a
        /// different mechanism entirely, not a bigger number here.
        /// </remarks>
        private const int ExportCap = 5000;

        // GET /api/admin/payments/export
        public async Task<ActionResult<PaymentExportResponse>> ExportAsync(
            string? status, DateTime? from, DateTime? to, CancellationToken ct)
        {
            var query = ApplyFilters(_db.Set<PaymentTransaction>().AsNoTracking(), status, from, to);

            var matchingCount = await query.CountAsync(ct);

            var payments = await query
                .OrderByDescending(p => p.CreatedAt)
                .Take(ExportCap)
                .Select(ToResponse())
                .ToListAsync(ct);

            return new OkObjectResult(new PaymentExportResponse
            {
                Payments = payments,
                MatchingCount = matchingCount,
                Truncated = matchingCount > payments.Count
            });
        }

        /// <summary>
        /// The filters shared by the live admin list and the export pull, kept
        /// in one place so the two can never quietly disagree on what "matching
        /// this filter" means.
        /// </summary>
        private static IQueryable<PaymentTransaction> ApplyFilters(
            IQueryable<PaymentTransaction> query, string? status, DateTime? from, DateTime? to)
        {
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<PaymentStatus>(status, true, out var parsedStatus))
                query = query.Where(p => p.Status == parsedStatus);

            // A date with no zone on it arrives as Kind=Unspecified, which Npgsql
            // refuses to compare with a timestamptz column - that was a 500 on
            // the Payment Log the moment a range was picked. Read it as UTC.
            if (from is { Kind: DateTimeKind.Unspecified }) from = DateTime.SpecifyKind(from.Value, DateTimeKind.Utc);
            if (to is { Kind: DateTimeKind.Unspecified }) to = DateTime.SpecifyKind(to.Value, DateTimeKind.Utc);

            // CreatedAt, not PaidAt: every row has one regardless of whether it
            // ever settled, so a date range does not silently drop unpaid bills.
            if (from is not null) query = query.Where(p => p.CreatedAt >= from);
            if (to is not null) query = query.Where(p => p.CreatedAt <= to);

            return query;
        }

        // GET /api/admin/payments/rates
        public async Task<ActionResult<List<ParkingRateResponse>>> ListRatesAsync(CancellationToken ct)
        {
            var rates = await _db.Set<ParkingRate>().AsNoTracking()
                .OrderBy(r => r.VehicleType)
                .Select(r => new ParkingRateResponse
                {
                    RateId = r.Id,
                    VehicleType = r.VehicleType == null ? null : r.VehicleType.ToString(),
                    RatePerHour = r.RatePerHour,
                    MinimumFee = r.MinimumFee,
                    UpdatedAt = r.UpdatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(rates);
        }

        // PUT /api/admin/payments/rates
        public async Task<ActionResult<object>> UpsertRateAsync(UpsertParkingRateDto dto, CancellationToken ct)
        {
            if (dto.RatePerHour < 0)
                return new BadRequestObjectResult(new { message = "Rate must be zero or greater." });

            if (dto.MinimumFee is < 0)
                return new BadRequestObjectResult(new { message = "Minimum fee must be zero or greater." });

            // A rate is for a vehicle type: Car or Motorcycle. The old blank "default"
            // rate is gone, so a blank type is refused rather than quietly saved
            // as a rate that applies to everything.
            if (string.IsNullOrWhiteSpace(dto.VehicleType)
                || !Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType)
                || !Enum.IsDefined(vehicleType))
                return new BadRequestObjectResult(new { message = "Choose a vehicle type: Car or Motorcycle." });

            var existing = await _rates.FindAsync(r => r.VehicleType == vehicleType, ct);
            if (existing is not null)
            {
                var newMinimum = dto.MinimumFee ?? existing.MinimumFee;

                // Saving the same numbers again is not a change: it must not move
                // the date a parked car's rate is locked against, or tell
                // everyone the rate changed when it did not.
                if (existing.RatePerHour == dto.RatePerHour && existing.MinimumFee == newMinimum)
                    return new OkObjectResult(new { message = "No change: the rate is already set to that." });

                var oldRate = existing.RatePerHour;
                var oldMinimum = existing.MinimumFee;

                // Cars already inside keep the old rate (see RateForAsync).
                existing.PreviousRatePerHour = oldRate;
                existing.PreviousMinimumFee = oldMinimum;
                existing.RatePerHour = dto.RatePerHour;
                existing.MinimumFee = newMinimum;
                existing.UpdatedAt = DateTime.UtcNow;
                _rates.Update(existing);
                await _rates.SaveAsync(ct);

                await _notificationService.AnnounceAsync(
                    NotificationType.PolicyUpdate,
                    $"{vehicleType} parking rate changed",
                    RateChangeMessage(vehicleType, oldRate, oldMinimum, dto.RatePerHour, newMinimum),
                    ct);

                return new OkObjectResult(new { message = "Rate saved. Drivers have been notified." });
            }
            else
            {
                await _rates.AddAsync(new ParkingRate
                {
                    Id = Guid.NewGuid(),
                    VehicleType = vehicleType,
                    RatePerHour = dto.RatePerHour,
                    MinimumFee = dto.MinimumFee ?? 20.00m,
                    UpdatedAt = DateTime.UtcNow
                }, ct);
            }

            await _rates.SaveAsync(ct);

            await _notificationService.AnnounceAsync(
                NotificationType.PolicyUpdate,
                $"{vehicleType} parking rate set",
                $"{vehicleType} parking is now ₱{dto.RatePerHour:0.00} an hour " +
                $"(minimum ₱{dto.MinimumFee ?? 20.00m:0.00}). Vehicles already parked keep the rate they came in with.",
                ct);

            return new OkObjectResult(new { message = "Rate saved. Drivers have been notified." });
        }

        /// <summary>"Car parking is now ₱20.00 an hour (was ₱15.00). ..."</summary>
        private static string RateChangeMessage(
            VehicleType type, decimal oldRate, decimal oldMinimum, decimal newRate, decimal newMinimum)
        {
            var message = $"{type} parking is now ₱{newRate:0.00} an hour (was ₱{oldRate:0.00}).";
            if (newMinimum != oldMinimum)
                message += $" The minimum fee is now ₱{newMinimum:0.00} (was ₱{oldMinimum:0.00}).";
            return message + " Vehicles already parked keep the rate they came in with.";
        }

        // DELETE /api/admin/payments/rates/{rateId}
        public async Task<ActionResult<object>> DeleteRateAsync(Guid rateId, CancellationToken ct)
        {
            var rate = await _rates.FindAsync(r => r.Id == rateId, ct);
            if (rate is null)
                return new NotFoundObjectResult(new { message = "That rate no longer exists." });

            // Refuse a removal that would leave a vehicle type with no rate at all.
            // QuoteForCompletedLogAsync bills a session with no rate as free, and
            // nobody means to give parking away by tidying up the rate list.
            var others = await _rates.GetAllAsync(r => r.Id != rateId, ct);
            var hasDefault = others.Any(r => r.VehicleType is null);
            var uncovered = Enum.GetValues<VehicleType>()
                .Where(t => !hasDefault && others.All(r => r.VehicleType != t))
                .ToList();
            if (uncovered.Count > 0)
            {
                var names = string.Join(" and ", uncovered.Select(t => t == VehicleType.Car ? "Car" : "Motorcycle"));
                return new BadRequestObjectResult(new
                {
                    message = $"Set a rate for {names} first. Without one, those vehicles would park for free."
                });
            }

            _rates.Delete(rate);
            await _rates.SaveAsync(ct);

            return new OkObjectResult(new { message = "Rate removed." });
        }

        private async Task<ActionResult<PaymentListResponse>> ListAsync(
            IQueryable<PaymentTransaction> query, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var totalCount = await query.CountAsync(ct);

            var payments = await query
                .OrderByDescending(p => p.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(ToResponse())
                .ToListAsync(ct);

            return new OkObjectResult(new PaymentListResponse
            {
                Payments = payments,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        /// <summary>
        /// An instance method rather than a static one, so the projection can
        /// reach the users table for the name behind
        /// <see cref="PaymentTransaction.ConfirmedByUserId"/>. Recording who took
        /// a cash payment and then never showing it would be a record kept for
        /// nobody.
        /// </summary>
        private System.Linq.Expressions.Expression<Func<PaymentTransaction, PaymentResponse>> ToResponse() => p => new PaymentResponse
        {
            PaymentId = p.Id,
            Source = p.Source.ToString(),
            ParkingLogId = p.ParkingLogId,
            ViolationId = p.ViolationId,
            PayerName = p.User != null ? p.User.FullName : null,
            SlotCode = p.ParkingLog != null && p.ParkingLog.Slot != null ? p.ParkingLog.Slot.SlotCode : null,
            EntryTime = p.ParkingLog != null ? p.ParkingLog.EntryTime : (DateTime?)null,
            ExitTime = p.ParkingLog != null ? p.ParkingLog.ExitTime : null,
            DurationMinutes = p.DurationMinutes,
            RatePerHourApplied = p.RatePerHourApplied,
            AmountDue = p.AmountDue,
            Status = p.Status.ToString(),
            DueAt = p.DueAt,
            CreatedAt = p.CreatedAt,
            PaidAt = p.PaidAt,
            CoversFrom = p.CoversFrom,
            CoversTo = p.CoversTo,
            GraceUntil = p.Source == PaymentSource.ParkingFee && p.PaidAt != null
                ? p.PaidAt.Value.AddMinutes(_graceMinutes)
                : (DateTime?)null,
            CheckoutStartedAt = p.CheckoutStartedAt,
            Method = p.Method != null ? p.Method.ToString() : null,
            ReferenceNumber = p.ReferenceNumber,
            Provider = p.Provider,
            ConfirmedBy = p.ConfirmedByUserId == null
                ? null
                : _db.Set<User>()
                    .Where(u => u.Id == p.ConfirmedByUserId)
                    .Select(u => u.FullName)
                    .FirstOrDefault()
        };
    }
}
