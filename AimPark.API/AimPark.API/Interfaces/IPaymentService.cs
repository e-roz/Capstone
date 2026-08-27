using AimPark.API.DTOs;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IPaymentService
    {
        // Internal — called by ParkingHistoryService right after a session's ExitTime is recorded.
        Task<PaymentTransaction> CreateForCompletedLogAsync(ParkingLog log, CancellationToken ct);

        /// <summary>
        /// What a finished session costs, without recording anything.
        /// </summary>
        /// <remarks>
        /// For visitors. They have no account to bill, so there is no
        /// <c>PaymentTransaction</c> to raise and nowhere to send a "you owe
        /// this" notification — but the guard at the barrier still has to be
        /// told what to collect in cash.
        /// </remarks>
        Task<ParkingFeeQuote> QuoteForCompletedLogAsync(ParkingLog log, CancellationToken ct);

        // Internal — called by ViolationService when a violation carrying a penalty is issued.
        Task<PaymentTransaction> CreateForViolationAsync(Violation violation, CancellationToken ct);

        // Internal — called by ViolationService when an appeal is approved. No-ops if the
        // associated payment is already Paid (out of scope: real-world refund handling).
        Task WaiveForViolationAsync(Guid violationId, CancellationToken ct);

        /// <summary>
        /// Re-prices the outstanding fee for a violation whose penalty was
        /// corrected. Only touches a still-pending transaction — an already-paid
        /// or waived one is settled and must not be rewritten.
        /// </summary>
        Task UpdateViolationAmountAsync(Guid violationId, decimal amountDue, CancellationToken ct);

        Task<ActionResult<PaymentListResponse>> GetMyPaymentsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<PaymentResponse>> GetMyPaymentDetailAsync(Guid userId, Guid paymentId, CancellationToken ct);
        Task<ActionResult<object>> PayAsync(Guid userId, Guid paymentId, CancellationToken ct);
        Task<ActionResult<PaymentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<List<ParkingRateResponse>>> ListRatesAsync(CancellationToken ct);
        Task<ActionResult<object>> UpsertRateAsync(UpsertParkingRateDto dto, CancellationToken ct);
    }

    /// <summary>The fee for one finished session.</summary>
    public record ParkingFeeQuote(int DurationMinutes, decimal RatePerHour, decimal AmountDue);
}

