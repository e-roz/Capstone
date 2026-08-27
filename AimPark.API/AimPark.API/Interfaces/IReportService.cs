using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IReportService
    {
        Task<ActionResult<ReportsSummaryResponse>> GetSummaryAsync(CancellationToken ct);
        Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrendAsync(int days, CancellationToken ct);
        Task<ActionResult<PeakHoursResponse>> GetPeakHoursAsync(int days, CancellationToken ct);
        Task<ActionResult<EntryExitReportResponse>> GetEntryExitReportAsync(int days, CancellationToken ct);
        Task<ActionResult<ViolationBreakdownResponse>> GetViolationBreakdownAsync(CancellationToken ct);
        Task<ActionResult<RevenueTrendResponse>> GetRevenueTrendAsync(int days, CancellationToken ct);
    }
}
