using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 2, for accounting: every peso received in the period, line by
    /// line, so it can be matched against the GCash/Maya statements and the
    /// cash box; and what is still owed.
    /// </summary>
    public class CollectionsReport(IReportService reports, AppDbContext db) : IPdfReport
    {
        public string Kind => "collections";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await reports.ResolvePeriodAsync(query, ct);

            var paid = await db.PaymentTransactions.AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Paid && p.PaidAt != null
                         && p.PaidAt >= period.StartUtc && p.PaidAt < period.EndUtc)
                .OrderBy(p => p.PaidAt)
                .Select(p => new
                {
                    p.Id,
                    PaidAt = p.PaidAt!.Value,
                    p.ReferenceNumber,
                    Name = p.User.FullName,
                    Plate = p.ParkingLog != null ? p.ParkingLog.AlprPlateNumber
                          : p.Violation != null && p.Violation.ParkingLog != null ? p.Violation.ParkingLog.AlprPlateNumber
                          : null,
                    p.Source,
                    p.Method,
                    p.Provider,
                    p.AmountDue
                })
                .ToListAsync(ct);

            var waived = await db.PaymentTransactions
                .CountAsync(p => p.Status == PaymentStatus.Waived
                              && p.CreatedAt >= period.StartUtc && p.CreatedAt < period.EndUtc, ct);

            // Live, not by period: what is owed is owed whenever it was billed.
            var unpaid = await db.PaymentTransactions.AsNoTracking()
                .Where(p => p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Processing)
                .OrderBy(p => p.CreatedAt)
                .Select(p => new { p.CreatedAt, Name = p.User.FullName, p.Source, p.Status, p.DueAt, p.AmountDue })
                .ToListAsync(ct);

            var now = DateTime.UtcNow;
            var fees = paid.Where(p => p.Source == PaymentSource.ParkingFee).Sum(p => p.AmountDue);
            var fines = paid.Where(p => p.Source == PaymentSource.ViolationPenalty).Sum(p => p.AmountDue);
            var total = fees + fines;
            var owed = unpaid.Sum(p => p.AmountDue);
            var testRows = paid.Count(p => p.Provider == "Simulated");

            var byMethod = paid
                .GroupBy(p => p.Method?.ToString() ?? "Not recorded")
                .OrderByDescending(g => g.Sum(p => p.AmountDue))
                .Select(g => new[] { g.Key, Count(g.Count()), Money(g.Sum(p => p.AmountDue)) })
                .ToList();

            var figures = new List<KeyFigure>
            {
                new("Payments received", Count(paid.Count)),
                new("Parking fees", Money(fees)),
                new("Fines", Money(fines)),
                new("Total collected", Money(total)),
            };

            return new ReportContent(
                Title: "Collection report",
                FileStem: "collections",
                SecondSignatureCaption: "Checked by (Accounting)",
                PeriodText: $"Period: {Period(period.First, period.Last)}",
                From: period.First,
                To: period.Last,
                KeyFigures: [.. figures, new("Unpaid at time of printing", Money(owed))],
                Body: col =>
                {
                    Figures(col, figures);

                    Section(col, "By payment method");
                    Table(col, ["Method", ">Payments", ">Amount"], [3, 1, 1.4f], byMethod,
                        totalRow: ["Total", Count(paid.Count), Money(total)],
                        empty: "No payments were received in this period.");
                    if (waived > 0)
                        Note(col, $"{Plural(waived, "bill was", "bills were")} waived in this period and are not counted as money received.");
                    if (testRows > 0)
                        Note(col, $"{Plural(testRows, "payment was", "payments were")} settled through the test gateway and are marked (test) below. No real money moved for these.");

                    Section(col, "Payments received", "in the order they were paid");
                    Table(col,
                        ["Date paid", "Reference", "Name", "Plate", "Type", "Method", ">Amount"],
                        [1.5f, 1.6f, 2.4f, 1.1f, 0.8f, 1.1f, 1.1f],
                        paid.Select(p => new[]
                        {
                            Short(p.PaidAt),
                            p.ReferenceNumber ?? p.Id.ToString("N")[..8].ToUpperInvariant(),
                            p.Name,
                            p.Plate ?? "—",
                            p.Source == PaymentSource.ParkingFee ? "Fee" : "Fine",
                            (p.Method?.ToString() ?? "—") + (p.Provider == "Simulated" ? " (test)" : ""),
                            Money(p.AmountDue)
                        }),
                        totalRow: ["Total collected", "", "", "", "", "", Money(total)],
                        empty: "No payments were received in this period.");

                    Section(col, "Still unpaid", "every open bill at the time of printing, any period");
                    Table(col,
                        ["Billed", "Name", "Type", "Status", "Due", ">Amount"],
                        [1.2f, 2.6f, 0.8f, 1.4f, 1.4f, 1.1f],
                        unpaid.Select(p => new[]
                        {
                            Date(p.CreatedAt),
                            p.Name,
                            p.Source == PaymentSource.ParkingFee ? "Fee" : "Fine",
                            p.Status == PaymentStatus.Processing ? "Checkout started" : "Not paid",
                            p.DueAt is DateTime due ? (due < now ? $"Overdue ({Date(due)})" : Date(due)) : "—",
                            Money(p.AmountDue)
                        }),
                        totalRow: ["Total owed", "", "", "", "", Money(owed)],
                        empty: "Nothing is owed right now.");
                });
        }
    }
}
