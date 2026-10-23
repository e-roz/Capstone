using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IUserHistoryService
    {
        Task<ActionResult<UserHistorySummary>> GetSummaryAsync(Guid userId, CancellationToken ct);

        Task<ActionResult<UserHistoryPage<UserSessionItem>>> GetSessionsAsync(
            Guid userId, int page, int pageSize, DateTime? from, DateTime? to, int? gate, CancellationToken ct);

        Task<ActionResult<UserHistoryPage<UserViolationItem>>> GetViolationsAsync(
            Guid userId, int page, int pageSize, CancellationToken ct);

        Task<ActionResult<UserIncidents>> GetIncidentsAsync(Guid userId, CancellationToken ct);

        Task<ActionResult<UserHistoryPage<UserPaymentItem>>> GetPaymentsAsync(
            Guid userId, int page, int pageSize, CancellationToken ct);
    }
}
