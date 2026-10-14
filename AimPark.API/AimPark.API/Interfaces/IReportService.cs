using AimPark.API.DTOs;
using AimPark.API.Helpers;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IReportService
    {
        Task<ActionResult<ReportsSummaryResponse>> GetSummaryAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrendAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<PeakHoursResponse>> GetPeakHoursAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<EntryExitReportResponse>> GetEntryExitReportAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<ViolationBreakdownResponse>> GetViolationBreakdownAsync(ReportQuery? query, CancellationToken ct);
        Task<ActionResult<RevenueTrendResponse>> GetRevenueTrendAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<GateOutcomesResponse>> GetGateOutcomesAsync(ReportQuery query, CancellationToken ct);
        Task<ActionResult<PeakOccupancyResponse>> GetPeakOccupancyAsync(ReportQuery query, CancellationToken ct);
    }
}
