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

        /// <summary>
        /// What the session would cost if it ended at <paramref name="at"/>, without
        /// recording anything. Used at the exit gate, before the session is closed.
        /// </summary>
        Task<ParkingFeeQuote> QuoteAsync(ParkingLog log, DateTime at, CancellationToken ct);

        /// <summary>The bill for this session, if one has been raised yet.</summary>
        Task<PaymentTransaction?> FindForLogAsync(Guid parkingLogId, CancellationToken ct);

        /// <summary>
        /// Raises the bill for a session whose driver has tapped out but not yet
        /// paid, or returns the one already raised. The amount is frozen at the
        /// first tap, so it cannot change under a driver who is already paying.
        /// </summary>
        Task<PaymentTransaction> RaiseExitBillAsync(ParkingLog log, DateTime at, CancellationToken ct);

        /// <summary>
        /// Raises the bill for a session the driver wants to pay while still
        /// parked, priced up to <paramref name="at"/>. A paid-ahead bill not yet
        /// paid is priced again; any other bill already on the session is
        /// returned as it is. Null when there is nothing to pay.
        /// </summary>
        Task<PaymentTransaction?> RaiseAheadAsync(ParkingLog log, DateTime at, CancellationToken ct);

        /// <summary>
        /// Bills a driver who paid but tapped out after the grace window for the
        /// rest of the stay: what it costs up to <paramref name="at"/>, less what
        /// the session was billed already. Null when that is nothing.
        /// <paramref name="paidAhead"/> when the driver asked for it from the app
        /// while still parked, rather than being held for it at the gate.
        /// </summary>
        Task<PaymentTransaction?> RaiseOverstayBillAsync(
            ParkingLog log, DateTime at, bool paidAhead, CancellationToken ct);

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

    /// <summary>The fee for one finished session.</summary>
    public record ParkingFeeQuote(int DurationMinutes, decimal RatePerHour, decimal AmountDue);
}

