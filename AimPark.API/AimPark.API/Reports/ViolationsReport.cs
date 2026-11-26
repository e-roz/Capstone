using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 3, for the security or discipline office: what was issued, where
    /// each case stands, which rules are broken most, and who keeps breaking them.
    /// </summary>
    public class ViolationsReport(IReportService reports, AppDbContext db) : IPdfReport
    {
        public string Kind => "violations";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await reports.ResolvePeriodAsync(query, ct);

            var issued = await db.Violations.AsNoTracking()
                .Where(v => v.CreatedAt >= period.StartUtc && v.CreatedAt < period.EndUtc)
                .OrderBy(v => v.CreatedAt)
                .Select(v => new
                {
                    v.CreatedAt,
                    v.UserId,
                    Name = v.User.FullName,
                    v.User.StudentNumber,
                    Rule = v.PolicyRule.Title,
                    v.PenaltyAmount,
                    v.Status
                })
                .ToListAsync(ct);

            // Repeat offenders: two or more that still stand in this period.
            // A dismissed one, or an appeal the user won, counts against nobody.
            var repeat = issued
                .Where(v => Stands(v.Status))
                .GroupBy(v => v.UserId)
                .Where(g => g.Count() >= 2)
                .ToList();
            var repeatIds = repeat.Select(g => g.Key).ToList();

            // Strikes are all-time: the third Accountable one costs the card.
            var strikes = await db.Violations
                .Where(v => repeatIds.Contains(v.UserId) && v.Status == ViolationStatus.Accountable)
                .GroupBy(v => v.UserId)
                .Select(g => new { UserId = g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.UserId, x => x.Count, ct);
            var cards = await db.Users
                .Where(u => repeatIds.Contains(u.Id))
                .Select(u => new { u.Id, u.RfidStatus })
                .ToDictionaryAsync(u => u.Id, u => u.RfidStatus, ct);

            int Of(ViolationStatus s) => issued.Count(v => v.Status == s);
            var standing = issued.Where(v => Stands(v.Status)).ToList();
            var penalties = standing.Sum(v => v.PenaltyAmount);

            var figures = new List<KeyFigure>
            {
                new("Violations issued", Count(issued.Count)),
                new("Accountable", Count(Of(ViolationStatus.Accountable)), "final, fine is owed"),
                new("Still open", Count(Of(ViolationStatus.Issued) + Of(ViolationStatus.PendingAppeal)), "appeal window or appeal pending"),
                new("Cleared", Count(Of(ViolationStatus.Appealed) + Of(ViolationStatus.Dismissed)), "appeal won or dismissed"),
            };

            var byRule = issued
                .GroupBy(v => v.Rule)
                .OrderByDescending(g => g.Count())
                .Select(g => new[]
                {
                    g.Key,
                    Count(g.Count()),
                    Count(g.Count(v => !Stands(v.Status))),
                    Money(g.Where(v => Stands(v.Status)).Sum(v => v.PenaltyAmount))
                })
                .ToList();

            return new ReportContent(
                Title: "Violations report",
                FileStem: "violations",
                SecondSignatureCaption: "Noted by (Security / Discipline Office)",
                PeriodText: $"Period: {Period(period.First, period.Last)}",
                From: period.First,
                To: period.Last,
                KeyFigures: [.. figures, new("Penalties on standing violations", Money(penalties)), new("Repeat offenders", Count(repeat.Count))],
                Body: col =>
                {
                    Figures(col, figures);
                    Note(col, $"Penalties on violations that still stand: {Money(penalties)}. Whether they are paid is on the collection report.");

                    Section(col, "By status");
                    Pairs(col,
                    [
                        (ReportText.ViolationStatus(ViolationStatus.Issued), Count(Of(ViolationStatus.Issued))),
                        (ReportText.ViolationStatus(ViolationStatus.PendingAppeal), Count(Of(ViolationStatus.PendingAppeal))),
                        (ReportText.ViolationStatus(ViolationStatus.Accountable), Count(Of(ViolationStatus.Accountable))),
                        (ReportText.ViolationStatus(ViolationStatus.Appealed), Count(Of(ViolationStatus.Appealed))),
                        (ReportText.ViolationStatus(ViolationStatus.Dismissed), Count(Of(ViolationStatus.Dismissed))),
                    ]);

                    Section(col, "By rule");
                    Table(col, ["Rule", ">Issued", ">Cleared", ">Penalties"], [4, 1, 1, 1.3f], byRule,
                        empty: "No violations were issued in this period.");

                    Section(col, "Repeat offenders", "two or more standing violations in this period");
                    Table(col,
                        ["Name", "Student no.", ">This period", ">Strikes (all time)", "Card"],
                        [2.6f, 1.3f, 1, 1.3f, 1.1f],
                        repeat
                            .OrderByDescending(g => g.Count())
                            .Select(g => new[]
                            {
                                g.First().Name,
                                g.First().StudentNumber ?? "—",
                                Count(g.Count()),
                                $"{strikes.GetValueOrDefault(g.Key)} of 3",
                                ReportText.Humanize(cards.GetValueOrDefault(g.Key))
                            }),
                        empty: "Nobody has more than one standing violation in this period.");

                    Section(col, "All violations issued");
                    Table(col,
                        ["Date", "Name", "Student no.", "Rule", ">Penalty", "Status"],
                        [1.1f, 2.2f, 1.2f, 2.4f, 1, 1.3f],
                        issued.Select(v => new[]
                        {
                            Date(v.CreatedAt),
                            v.Name,
                            v.StudentNumber ?? "—",
                            v.Rule,
                            Money(v.PenaltyAmount),
                            ReportText.ViolationStatus(v.Status)
                        }),
                        empty: "No violations were issued in this period.");
                });
        }

        private static bool Stands(ViolationStatus s) =>
            s is not (ViolationStatus.Dismissed or ViolationStatus.Appealed);
    }
}
