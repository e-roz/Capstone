using System.Security.Cryptography;
using System.Text.Json;
using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Helpers;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Reports
{
    public record ReportFile(byte[] Bytes, string FileName, string Number);

    /// <summary>
    /// Makes a report: gathers its figures, gives it the next number, records
    /// what it showed, and draws the PDF.
    /// </summary>
    /// <remarks>
    /// The row is written before the PDF is drawn, because the number and the
    /// verify link are printed on it. A drawing failure after that leaves a gap
    /// in the numbering, which is honest: the number was issued.
    /// </remarks>
    public class ReportPdfService(
        IEnumerable<IPdfReport> reports,
        AppDbContext db,
        IConfiguration config,
        IHttpContextAccessor http,
        ILogger<ReportPdfService> logger)
    {
        private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

        public IReadOnlyCollection<string> Kinds => reports.Select(r => r.Kind).ToList();

        public async Task<ReportFile?> CreateAsync(string kind, ReportQuery query, Guid adminId, CancellationToken ct)
        {
            var report = reports.FirstOrDefault(r => string.Equals(r.Kind, kind, StringComparison.OrdinalIgnoreCase));
            if (report is null) return null;

            var content = await report.BuildAsync(query, ct);

            var adminName = await db.Users
                .Where(u => u.Id == adminId)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);

            var record = new GeneratedReport
            {
                Kind = report.Kind,
                Title = content.Title,
                PeriodFrom = content.From,
                PeriodTo = content.To,
                GeneratedByUserId = adminId,
                GeneratedByName = string.IsNullOrWhiteSpace(adminName) ? "Administrator" : adminName,
                GeneratedAt = DateTime.UtcNow,
                VerifyToken = Convert.ToHexString(RandomNumberGenerator.GetBytes(16)).ToLowerInvariant(),
                KeyFiguresJson = JsonSerializer.Serialize(
                    content.KeyFigures.Select(f => new { label = f.Label, value = f.Value }), Json)
            };

            await SaveWithNextNumberAsync(record, ct);

            var frame = new ReportFrame(
                SchoolName: config["Reports:SchoolName"] is { Length: > 0 } school ? school : "STI College Baliuag",
                Title: content.Title,
                PeriodText: content.PeriodText,
                Number: record.Number,
                GeneratedByName: record.GeneratedByName,
                GeneratedAtUtc: record.GeneratedAt,
                VerifyUrl: $"{PublicBaseUrl()}/api/reports/verify/{record.VerifyToken}",
                SecondSignatureCaption: content.SecondSignatureCaption);

            var bytes = PdfLayout.Render(frame, content.Body);
            var day = PdfLayout.Local(record.GeneratedAt).ToString("yyyyMMdd");
            return new ReportFile(bytes, $"aimpark-{content.FileStem}-{day}-{record.Number}.pdf", record.Number);
        }

        public Task<GeneratedReport?> FindByTokenAsync(string token, CancellationToken ct) =>
            db.GeneratedReports.AsNoTracking().FirstOrDefaultAsync(r => r.VerifyToken == token, ct);

        /// <summary>
        /// RPT-yyyy-MM-nnnn, counting from 1 each Philippine month. Two admins
        /// printing at the same instant can pick the same next number; the
        /// unique index refuses the second, which simply tries the one after.
        /// </summary>
        private async Task SaveWithNextNumberAsync(GeneratedReport record, CancellationToken ct)
        {
            var prefix = $"RPT-{PdfLayout.Local(record.GeneratedAt):yyyy-MM}-";

            for (var attempt = 0; ; attempt++)
            {
                var taken = await db.GeneratedReports
                    .Where(r => r.Number.StartsWith(prefix))
                    .Select(r => r.Number)
                    .ToListAsync(ct);
                var next = taken.Select(n => int.TryParse(n[prefix.Length..], out var i) ? i : 0)
                                .DefaultIfEmpty(0).Max() + 1;
                record.Number = $"{prefix}{next:D4}";

                db.GeneratedReports.Add(record);
                try
                {
                    await db.SaveChangesAsync(ct);
                    return;
                }
                catch (DbUpdateException ex) when (attempt < 4)
                {
                    logger.LogInformation(ex, "Report number {Number} was taken; trying the next one", record.Number);
                    db.Entry(record).State = EntityState.Detached;
                }
            }
        }

        /// <summary>
        /// Where a phone scanning the QR code can reach this API. Render sits
        /// behind a proxy that talks plain http to the app, so the request's own
        /// scheme says http; an address that is not this machine is assumed https.
        /// </summary>
        private string PublicBaseUrl()
        {
            var configured = config["Reports:PublicBaseUrl"];
            if (string.IsNullOrWhiteSpace(configured)) configured = config["Payments:PublicBaseUrl"];
            if (!string.IsNullOrWhiteSpace(configured)) return configured.TrimEnd('/');

            var request = http.HttpContext?.Request;
            if (request is null) return string.Empty;
            var host = request.Host.Host;
            var local = host is "localhost" or "127.0.0.1" or "::1" || host.StartsWith("192.168.") || host.StartsWith("10.");
            return $"{(local ? request.Scheme : "https")}://{request.Host}";
        }
    }
}
