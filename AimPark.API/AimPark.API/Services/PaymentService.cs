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
        private readonly IRepository<PaymentTransaction> _payments;
        private readonly IRepository<ParkingRate> _rates;
        private readonly AppDbContext _db;

        public PaymentService(IRepository<PaymentTransaction> payments, IRepository<ParkingRate> rates, AppDbContext db)
        {
            _payments = payments;
            _rates = rates;
            _db = db;
        }

        // Called by ParkingHistoryService.LogExitAsync right after ExitTime is recorded.
        public async Task<PaymentTransaction> CreateForCompletedLogAsync(ParkingLog log, CancellationToken ct)
        {
            string? vehicleType = null;
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
            var durationMinutes = Math.Max(0, (int)Math.Round((log.ExitTime!.Value - log.EntryTime).TotalMinutes));
            var amountDue = Math.Round(ratePerHour / 60m * durationMinutes, 2);

            var transaction = new PaymentTransaction
            {
                Id = Guid.NewGuid(),
                Source = PaymentSource.ParkingFee,
                ParkingLogId = log.Id,
                UserId = log.UserId,
                DurationMinutes = durationMinutes,
                RatePerHourApplied = ratePerHour,
                AmountDue = amountDue,
                Status = PaymentStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            await _payments.AddAsync(transaction, ct);
            await _payments.SaveAsync(ct);

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
            if (payment is null || payment.Status != PaymentStatus.Pending)
                return;

            payment.Status = PaymentStatus.Waived;
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
        public async Task<ActionResult<object>> PayAsync(Guid userId, Guid paymentId, CancellationToken ct)
        {
            var payment = await _payments.FindAsync(p => p.Id == paymentId && p.UserId == userId, ct);
            if (payment is null)
                return new NotFoundObjectResult(new { message = "Payment not found." });

            if (payment.Status != PaymentStatus.Pending)
                return new BadRequestObjectResult(new { message = "This payment is not pending." });

            payment.Status = PaymentStatus.Paid;
            payment.PaidAt = DateTime.UtcNow;

            _payments.Update(payment);
            await _payments.SaveAsync(ct);

            return new OkObjectResult(new { message = "Payment successful." });
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
                    VehicleType = r.VehicleType,
                    RatePerHour = r.RatePerHour,
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

            var existing = await _rates.FindAsync(r => r.VehicleType == dto.VehicleType, ct);
            if (existing is not null)
            {
                existing.RatePerHour = dto.RatePerHour;
                existing.UpdatedAt = DateTime.UtcNow;
                _rates.Update(existing);
            }
            else
            {
                await _rates.AddAsync(new ParkingRate
                {
                    Id = Guid.NewGuid(),
                    VehicleType = dto.VehicleType,
                    RatePerHour = dto.RatePerHour,
                    UpdatedAt = DateTime.UtcNow
                }, ct);
            }

            await _rates.SaveAsync(ct);

            return new OkObjectResult(new { message = "Rate saved." });
        }

        private static async Task<ActionResult<PaymentListResponse>> ListAsync(
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

        private static System.Linq.Expressions.Expression<Func<PaymentTransaction, PaymentResponse>> ToResponse() => p => new PaymentResponse
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
            CreatedAt = p.CreatedAt,
            PaidAt = p.PaidAt
        };
    }
}
