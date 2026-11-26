using System.Security.Claims;
using AimPark.API.Helpers;
using AimPark.API.Reports;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Controllers
{
    /// <summary>
    /// The printable reports. Same period parameters as the JSON reports:
    /// <c>days</c>, <c>from</c>/<c>to</c>, or <c>allTime=true</c>.
    /// </summary>
    /// <remarks>
    /// Kinds: summary, collections, violations, entry-exit, incidents, vehicles.
    /// Every call issues a new report number, so this is a GET that writes a
    /// row; that is deliberate. Each printout is its own numbered document,
    /// like a receipt book.
    /// </remarks>
    [ApiController]
    [Route("api/admin/reports/pdf")]
    [Authorize(Roles = "Admin")]
    public class AdminReportPdfController(ReportPdfService pdfs) : ControllerBase
    {
        [HttpGet("{kind}")]
        public async Task<IActionResult> Get(
            string kind,
            [FromQuery] int? days, [FromQuery] DateOnly? from, [FromQuery] DateOnly? to,
            [FromQuery] bool allTime = false, CancellationToken ct = default)
        {
            var query = new ReportQuery(days ?? 30, from, to, allTime);
            var adminId = Guid.Parse(User.FindFirst(ClaimTypes.NameIdentifier)!.Value);

            ReportFile? file;
            try
            {
                file = await pdfs.CreateAsync(kind, query, adminId, ct);
            }
            catch (ReportRequestException ex)
            {
                return BadRequest(new { message = ex.Message });
            }

            if (file is null)
                return NotFound(new { message = $"There is no report called \"{kind}\". Try one of: {string.Join(", ", pdfs.Kinds)}." });

            Response.Headers["X-Report-Number"] = file.Number;
            return File(file.Bytes, "application/pdf", file.FileName);
        }
    }
}
