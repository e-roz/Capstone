using AimPark.API.DTOs;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// Every report answers the same three ways: <c>days</c> (the last N days,
    /// up to 90), <c>from</c> and <c>to</c> (Philippine dates, <c>yyyy-MM-dd</c>,
    /// inclusive), or <c>allTime=true</c>. Long ranges come back one point per
    /// week or month; the response's <c>period</c> says which.
    /// </summary>
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

        /// <summary>
        /// With no range given the money and counts cover everything, as this
        /// endpoint always has. Free bays and "today" never depend on the range.
        /// </summary>
        [HttpGet("summary")]
        public Task<ActionResult<ReportsSummaryResponse>> GetSummary(
            [FromQuery] int? days, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
        {
            var noRange = days is null && from is null && to is null;
            return _reportService.GetSummaryAsync(new ReportQuery(days ?? 14, from, to, allTime || noRange), ct);
        }

        [HttpGet("occupancy-trend")]
        public Task<ActionResult<OccupancyTrendResponse>> GetOccupancyTrend(
            [FromQuery] int days = 14, [FromQuery] DateOnly? from = null, [FromQuery] DateOnly? to = null,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
            => _reportService.GetOccupancyTrendAsync(new ReportQuery(days, from, to, allTime), ct);

        /// <summary>
        /// Vehicles in and out per day. "Entry/Exit Reports" in the spec.
        /// </summary>
        [HttpGet("entry-exit")]
        public Task<ActionResult<EntryExitReportResponse>> GetEntryExit(
            [FromQuery] int days = 30, [FromQuery] DateOnly? from = null, [FromQuery] DateOnly? to = null,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
            => _reportService.GetEntryExitReportAsync(new ReportQuery(days, from, to, allTime), ct);

        [HttpGet("peak-hours")]
        public Task<ActionResult<PeakHoursResponse>> GetPeakHours(
            [FromQuery] int days = 30, [FromQuery] DateOnly? from = null, [FromQuery] DateOnly? to = null,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
            => _reportService.GetPeakHoursAsync(new ReportQuery(days, from, to, allTime), ct);

        [HttpGet("violations-breakdown")]
        public Task<ActionResult<ViolationBreakdownResponse>> GetViolationsBreakdown(
            [FromQuery] int? days, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
        {
            var asked = days is not null || from is not null || to is not null || allTime;
            return _reportService.GetViolationBreakdownAsync(
                asked ? new ReportQuery(days ?? 14, from, to, allTime) : null, ct);
        }

        [HttpGet("revenue-trend")]
        public Task<ActionResult<RevenueTrendResponse>> GetRevenueTrend(
            [FromQuery] int days = 14, [FromQuery] DateOnly? from = null, [FromQuery] DateOnly? to = null,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
            => _reportService.GetRevenueTrendAsync(new ReportQuery(days, from, to, allTime), ct);
    }
}
