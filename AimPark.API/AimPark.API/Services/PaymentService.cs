using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class PaymentService : IPaymentService
    {
        /// <summary>
        /// Grace period for a parking fee. Short — the driver has just left and
        /// the amount is small.
        /// </summary>
        private static readonly TimeSpan ParkingFeeDueWindow = TimeSpan.FromDays(7);

        /// <summary>
        /// Grace period for a violation penalty. Longer, because it is larger and
        /// because the appeal window has to fit inside it.
        /// </summary>
        private static readonly TimeSpan ViolationDueWindow = TimeSpan.FromDays(14);

        private readonly IRepository<PaymentTransaction> _payments;
        private readonly IRepository<ParkingRate> _rates;
        private readonly INotificationService _notificationService;
        private readonly AppDbContext _db;
        private readonly IPaymentGateway _gateway;
        private readonly ILogger<PaymentService> _logger;

        public PaymentService(
            IRepository<PaymentTransaction> payments,
            IRepository<ParkingRate> rates,
            INotificationService notificationService,
            AppDbContext db,
            IPaymentGateway gateway,
            ILogger<PaymentService> logger)
        {
            _payments = payments;
            _rates = rates;
            _notificationService = notificationService;
            _db = db;
            _gateway = gateway;
            _logger = logger;
        }

        // Called by ParkingHistoryService.LogExitAsync right after ExitTime is recorded.
        public async Task<ParkingFeeQuote> QuoteForCompletedLogAsync(ParkingLog log, CancellationToken ct)
        {
            VehicleType? vehicleType = null;
            if (log.SlotId is not null)
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

            var ratePerHour = rate?.RatePerHour ?? 0m;
            // Rounded up, not to nearest: a started minute is a charged minute,
            // which is how paid parking is billed everywhere. Rounding to
            // nearest also billed people for less time than they parked - a
            // 9:34:50 entry and a 9:36:10 exit is 1m20s, which came out as one
            // minute on a receipt showing two different clock minutes.
            var durationMinutes = Math.Max(0, (int)Math.Ceiling((log.ExitTime!.Value - log.EntryTime).TotalMinutes));
            var metered = Math.Round(ratePerHour / 60m * durationMinutes, 2);

            // A floor, not a fee on top. Twenty minutes at ₱15 an hour is five
            // pesos, and no card or e-wallet gateway in the country will take a
            // payment that small — so per-minute billing alone produced bills
            // that literally could not be settled online. Priced the way parking
            // is priced everywhere anyway: a flat first block, metered after it.
            //
            // A session that cost nothing stays nothing. There is no minimum to
            // apply to a driver who was never charged — a waived session, a
            // rate that has not been set.
            var minimum = rate?.MinimumFee ?? 0m;
            var amountDue = metered > 0m && metered < minimum ? minimum : metered;

            return new ParkingFeeQuote(durationMinutes, ratePerHour, amountDue);
        }

        public async Task<PaymentTransaction> CreateForCompletedLogAsync(ParkingLog log, CancellationToken ct)
        {
            if (log.UserId is null)
                throw new InvalidOperationException(
                    "A visitor session has no account to bill. Use QuoteForCompletedLogAsync.");

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
                DueAt = DateTime.UtcNow.Add(ParkingFeeDueWindow),
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            // The driver has just left; telling them what they owe now is the
            // difference between a fee they act on and one they discover later.
            var hours = durationMinutes / 60;
            var minutes = durationMinutes % 60;
            var duration = hours > 0 ? $"{hours}h {minutes}m" : $"{minutes}m";

            await _notificationService.NotifyUserAsync(
                log.UserId.Value,
                NotificationType.Payment,
                "Parking fee",
                $"You parked for {duration}. Amount due: ₱{amountDue:0.00}.",
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
                DueAt = DateTime.UtcNow.Add(ViolationDueWindow),
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

            return transaction;
        }

        // Called by ViolationService.DecideAppealAsync (approved) / DismissAsync.
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

        // Called by ViolationService.UpdateAsync when a penalty is corrected.
        public async Task UpdateViolationAmountAsync(Guid violationId, decimal amountDue, CancellationToken ct)
        {
            var payment = await _payments.FindAsync(p => p.ViolationId == violationId, ct);
            if (payment is null || payment.Status != PaymentStatus.Pending)
                return;

            payment.AmountDue = amountDue;
            _payments.Update(payment);
            await _payments.SaveAsync(ct);
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

        // POST /api/payments/callback  (the provider calls this, not the app)
        public async Task<bool> HandleGatewayCallbackAsync(
            string rawBody,
            IDictionary<string, string> headers,
            CancellationToken ct)
        {
            if (!_gateway.TryReadEvent(rawBody, headers, out var settlement)) return false;
            if (!settlement.Paid) return false;

            var payment = await _payments.FindAsync(
                p => p.ProviderPaymentId == settlement.ProviderPaymentId, ct);

            if (payment is null)
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
            if (payment.Status == PaymentStatus.Paid) return true;

            payment.Status = PaymentStatus.Paid;
            payment.PaidAt = DateTime.UtcNow;
            payment.Method = settlement.Method ?? PaymentMethod.GCash;
            payment.ReferenceNumber = settlement.ReferenceNumber;
            payment.Provider ??= _gateway.Name;

            _payments.Update(payment);
            await _payments.SaveAsync(ct);

            await _notificationService.NotifyUserAsync(
                payment.UserId,
                NotificationType.Payment,
                "Payment received",
                $"₱{payment.AmountDue:0.00} paid. Thank you.",
                new Dictionary<string, string> { ["paymentId"] = payment.Id.ToString() },
                ct);

            return true;
        }

        // POST /api/admin/payments/{paymentId}/mark-paid
        public async Task<ActionResult<object>> MarkPaidByAdminAsync(
            Guid paymentId,
            Guid adminUserId,
            MarkPaidDto dto,
            CancellationToken ct)
        {
            var payment = await _payments.FindAsync(p => p.Id == paymentId, ct);
            if (payment is null)
                return new NotFoundObjectResult(new { message = "Payment not found." });

            if (payment.Status == PaymentStatus.Paid)
                return new BadRequestObjectResult(new { message = "This bill is already paid." });

            if (payment.Status == PaymentStatus.Waived)
                return new BadRequestObjectResult(new { message = "This bill was waived." });

            var method = Enum.TryParse<PaymentMethod>(dto.Method, true, out var parsed)
                ? parsed
                : PaymentMethod.Cash;

            payment.Status = PaymentStatus.Paid;
            payment.PaidAt = DateTime.UtcNow;
            payment.Method = method;
            payment.ReferenceNumber = string.IsNullOrWhiteSpace(dto.ReferenceNumber)
                ? null
                : dto.ReferenceNumber.Trim();

            // The whole point of the row: online money lands in an account with a
            // provider's record behind it, and cash lands in somebody's hand.
            // This is the only thing that can say whose.
            payment.ConfirmedByUserId = adminUserId;
            payment.Provider = null;

            _payments.Update(payment);
            await _payments.SaveAsync(ct);

            await _notificationService.NotifyUserAsync(
                payment.UserId,
                NotificationType.Payment,
                "Payment recorded",
                $"₱{payment.AmountDue:0.00} received. Thank you.",
                new Dictionary<string, string> { ["paymentId"] = payment.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = $"Marked as paid ({method})." });
        }

        // GET /api/admin/payments
        public Task<ActionResult<PaymentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct)
        {
            var query = _db.Set<PaymentTransaction>().AsNoTracking();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<PaymentStatus>(status, true, out var parsedStatus))
                query = query.Where(p => p.Status == parsedStatus);

            return ListAsync(query, page, pageSize, ct);
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

            // A blank vehicle type means the default/fallback rate, not an invalid one.
            VehicleType? vehicleType = null;
            if (!string.IsNullOrWhiteSpace(dto.VehicleType))
            {
                if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var parsed))
                    return new BadRequestObjectResult(new { message = "Invalid vehicle type." });
                vehicleType = parsed;
            }

            var existing = await _rates.FindAsync(r => r.VehicleType == vehicleType, ct);
            if (existing is not null)
            {
                existing.RatePerHour = dto.RatePerHour;
                if (dto.MinimumFee is not null) existing.MinimumFee = dto.MinimumFee.Value;
                existing.UpdatedAt = DateTime.UtcNow;
                _rates.Update(existing);
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

            return new OkObjectResult(new { message = "Rate saved." });
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
