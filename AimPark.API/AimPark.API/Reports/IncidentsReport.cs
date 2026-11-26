using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 5, for security: what was reported in the lot, and whether each
    /// one was dealt with.
    /// </summary>
    public class IncidentsReport(IReportService reports, AppDbContext db) : IPdfReport
    {
        public string Kind => "incidents";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await reports.ResolvePeriodAsync(query, ct);

            // Withdrawn ones are the reporter taking it back before anyone
            // looked; they are counted, not listed.
            var all = await db.Incidents.AsNoTracking()
                .Where(i => i.CreatedAt >= period.StartUtc && i.CreatedAt < period.EndUtc)
                .OrderBy(i => i.CreatedAt)
                .Select(i => new
                {
                    i.CreatedAt,
                    i.Category,
                    i.Location,
                    i.SlotId,
                    Reporter = i.ReportedByUser.FullName,
                    i.Status,
                    i.ReviewedAt,
                    i.Description
                })
                .ToListAsync(ct);

            var withdrawn = all.Count(i => i.Status == IncidentStatus.Withdrawn);
            var incidents = all.Where(i => i.Status != IncidentStatus.Withdrawn).ToList();

            var slotIds = incidents.Where(i => i.SlotId != null).Select(i => i.SlotId!.Value).Distinct().ToList();
            var bays = await db.ParkingSlots
                .Where(s => slotIds.Contains(s.Id))
                .ToDictionaryAsync(s => s.Id, s => s.SlotCode, ct);

            int Of(params IncidentStatus[] s) => incidents.Count(i => s.Contains(i.Status));

            var figures = new List<KeyFigure>
            {
                new("Incidents reported", Count(incidents.Count)),
                new("Resolved", Count(Of(IncidentStatus.Resolved))),
                new("Dismissed", Count(Of(IncidentStatus.Dismissed))),
                new("Still open", Count(Of(IncidentStatus.Submitted, IncidentStatus.UnderReview)), "not yet decided"),
            };

            string Place(Guid? slotId, string? location)
            {
                var bay = slotId is Guid id && bays.TryGetValue(id, out var code) ? $"Bay {code}" : null;
                return (bay, string.IsNullOrWhiteSpace(location) ? null : location.Trim()) switch
                {
                    (null, null) => "—",
                    (string b, null) => b,
                    (null, string l) => ReportText.Clip(l, 40),
                    (string b, string l) => $"{b}, {ReportText.Clip(l, 30)}"
                };
            }

            return new ReportContent(
                Title: "Incident report",
                FileStem: "incidents",
                SecondSignatureCaption: "Noted by (Security)",
                PeriodText: $"Period: {Period(period.First, period.Last)}",
                From: period.First,
                To: period.Last,
                KeyFigures: figures,
                Body: col =>
                {
                    Figures(col, figures);
                    if (withdrawn > 0)
                        Note(col, $"{Plural(withdrawn, "report was", "reports were")} withdrawn by the reporter before review and are not listed.");

                    Section(col, "By category");
                    Table(col, ["Category", ">Reported", ">Resolved", ">Open"], [3, 1, 1, 1],
                        incidents
                            .GroupBy(i => i.Category)
                            .OrderByDescending(g => g.Count())
                            .Select(g => new[]
                            {
                                ReportText.Humanize(g.Key),
                                Count(g.Count()),
                                Count(g.Count(i => i.Status == IncidentStatus.Resolved)),
                                Count(g.Count(i => i.Status is IncidentStatus.Submitted or IncidentStatus.UnderReview))
                            }),
                        empty: "No incidents were reported in this period.");

                    Section(col, "All incidents");
                    Table(col,
                        ["Reported", "Category", "Where", "Reported by", "What happened", "Status", "Decided"],
                        [1.1f, 1.2f, 1.3f, 1.6f, 3, 1, 1.1f],
                        incidents.Select(i => new[]
                        {
                            Date(i.CreatedAt),
                            ReportText.Humanize(i.Category),
                            Place(i.SlotId, i.Location),
                            i.Reporter,
                            ReportText.Clip(i.Description, 120),
                            ReportText.Humanize(i.Status),
                            i.ReviewedAt is DateTime r ? Date(r) : "—"
                        }),
                        empty: "No incidents were reported in this period.");
                });
        }
    }
}
