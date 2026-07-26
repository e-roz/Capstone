using AimPark.API.DTOs;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    [ApiController]
    [Route("api/admin/reports")]
    [Authorize(Roles = "Admin")]
    public class AdminReportsController : ControllerBase
    {
        private readonly IReportService _reportService;

        public AdminReportsController(IReportService reportService)
        {
            _reportService = reportService;
        }

        [HttpGet("summary")]
        public Task<ActionResult<ReportsSummaryResponse>> GetSummary(CancellationToken ct)
            => _reportService.GetSummaryAsync(ct);

        [HttpGet("occupancy-trend")]
        public Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrend(
            [FromQuery] int days = 14, CancellationToken ct = default)
            => _reportService.GetOccupancyTrendAsync(days, ct);

        [HttpGet("peak-hours")]
        public Task<ActionResult<PeakHoursResponse>> GetPeakHours(
            [FromQuery] int days = 30, CancellationToken ct = default)
            => _reportService.GetPeakHoursAsync(days, ct);

        [HttpGet("violations-breakdown")]
        public Task<ActionResult<ViolationBreakdownResponse>> GetViolationsBreakdown(CancellationToken ct)
            => _reportService.GetViolationBreakdownAsync(ct);

        [HttpGet("revenue-trend")]
        public Task<ActionResult<RevenueTrendResponse>> GetRevenueTrend(
            [FromQuery] int days = 14, CancellationToken ct = default)
            => _reportService.GetRevenueTrendAsync(days, ct);
    }
}
