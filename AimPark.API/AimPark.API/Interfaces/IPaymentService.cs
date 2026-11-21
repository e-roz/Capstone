using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Services;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IPaymentService
    {
        /// <summary>
        /// Bills what <paramref name="price"/> says is owed now. Re-prices the open
        /// Pending bill if there is one, or makes a new one. A checkout already
        /// Processing is never re-priced; only time beyond it is billed. Null
        /// when nothing is owed: no ₱0 bills.
        /// </summary>
        Task<BillResult?> BillOwedAsync(ParkingLog log, VisitPrice price, bool paidAhead, CancellationToken ct);

        // Internal — called by ParkingHistoryService right after a session's ExitTime is recorded.
        // Bills what the visit still owes; null when nothing is.
        Task<PaymentTransaction?> CreateForCompletedLogAsync(ParkingLog log, VisitPrice price, CancellationToken ct);

        /// <summary>The hourly rate (and the stored minimum, which no longer prices anything) for this session.</summary>
        Task<(decimal RatePerHour, decimal MinimumFee)> RateForAsync(ParkingLog log, CancellationToken ct);

        /// <summary>The latest bill for this session, if one has been raised yet.</summary>
        Task<PaymentTransaction?> FindForLogAsync(Guid parkingLogId, CancellationToken ct);

        // Internal — called by ViolationService when a violation carrying a penalty is issued.
        Task<PaymentTransaction> CreateForViolationAsync(Violation violation, CancellationToken ct);

        // Internal — called by ViolationService when an appeal is approved. No-ops if the
        // associated payment is already Paid (out of scope: real-world refund handling).
        Task WaiveForViolationAsync(Guid violationId, CancellationToken ct);

        // Internal — called when a user's account is revoked: drops every violation fine still open.
        Task WaiveOpenPenaltiesForUserAsync(Guid userId, CancellationToken ct);

        Task<ActionResult<PaymentListResponse>> GetMyPaymentsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<PaymentResponse>> GetMyPaymentDetailAsync(Guid userId, Guid paymentId, CancellationToken ct);
        /// <summary>
        /// Opens a checkout with the payment provider and returns where to send
        /// the payer.
        /// </summary>
        /// <remarks>
        /// This replaced a <c>Pay</c> endpoint that set the row to Paid on the
        /// payer's own say-so. Nothing stopped anyone clearing their own bill
        /// with it, which is the one thing a payment system must not allow: the
        /// statement that money arrived has to come from whoever received it.
        /// </remarks>
        Task<ActionResult<CheckoutResponse>> StartCheckoutAsync(Guid userId, Guid paymentId, CancellationToken ct);

        /// <summary>One checkout covering every bill the caller can pay now ("Pay all").</summary>
        Task<ActionResult<CheckoutResponse>> StartCheckoutAllAsync(Guid userId, CancellationToken ct);

        /// <summary>
        /// Settles a bill from a provider's callback. Safe to call twice with the
        /// same message.
        /// </summary>
        Task<bool> HandleGatewayCallbackAsync(string rawBody, IDictionary<string, string> headers, CancellationToken ct);

        Task<ActionResult<PaymentListResponse>> ListAllAsync(string? status, DateTime? from, DateTime? to, int page, int pageSize, CancellationToken ct);

        /// <summary>
        /// Every transaction matching a filter, unpaged and capped — for
        /// downloading as a spreadsheet rather than paging through on screen.
        /// </summary>
        Task<ActionResult<PaymentExportResponse>> ExportAsync(string? status, DateTime? from, DateTime? to, CancellationToken ct);

        Task<ActionResult<List<ParkingRateResponse>>> ListRatesAsync(CancellationToken ct);
        Task<ActionResult<object>> UpsertRateAsync(UpsertParkingRateDto dto, CancellationToken ct);
        Task<ActionResult<object>> DeleteRateAsync(Guid rateId, CancellationToken ct);
    }

    /// <summary>A bill for what a visit owes now. <c>Created</c>: new, not re-priced.</summary>
    public sealed record BillResult(PaymentTransaction Bill, bool Created, bool WasPaidAhead);

}

