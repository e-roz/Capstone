using AimPark.API.DTOs;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IPaymentService
    {
        // Internal — called by ParkingHistoryService right after a session's ExitTime is recorded.
        Task<PaymentTransaction> CreateForCompletedLogAsync(ParkingLog log, CancellationToken ct);

        // Internal — called by ViolationService when a violation carrying a penalty is issued.
        Task<PaymentTransaction> CreateForViolationAsync(Violation violation, CancellationToken ct);

        // Internal — called by ViolationService when an appeal is approved. No-ops if the
        // associated payment is already Paid (out of scope: real-world refund handling).
        Task WaiveForViolationAsync(Guid violationId, CancellationToken ct);

        Task<ActionResult<PaymentListResponse>> GetMyPaymentsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<PaymentResponse>> GetMyPaymentDetailAsync(Guid userId, Guid paymentId, CancellationToken ct);
        Task<ActionResult<object>> PayAsync(Guid userId, Guid paymentId, CancellationToken ct);
        Task<ActionResult<PaymentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<List<ParkingRateResponse>>> ListRatesAsync(CancellationToken ct);
        Task<ActionResult<object>> UpsertRateAsync(UpsertParkingRateDto dto, CancellationToken ct);
    }
}
