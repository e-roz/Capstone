using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 1, for school administration: how much the lot was used, how full
    /// it got, what came in, and what was broken. Built from the same queries as
    /// the Reports page, so the paper and the screen never disagree.
    /// </summary>
    public class SummaryReport(IReportService reports, AppDbContext db) : IPdfReport
    {
        public string Kind => "summary";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await reports.ResolvePeriodAsync(query, ct);
            // Pinned to the resolved days: a bare "last 30 days" would otherwise
            // read as all time on the violations breakdown.
            var q = new ReportQuery(period.Days, period.First, period.Last);
            var compare = !query.AllTime;

            var summary = ReportText.Ok(await reports.GetSummaryAsync(q, ct));
            var entryExit = ReportText.Ok(await reports.GetEntryExitReportAsync(q, ct));
            var hours = ReportText.Ok(await reports.GetPeakHoursAsync(q, ct));
            var peak = ReportText.Ok(await reports.GetPeakOccupancyAsync(q, ct));
            var gate = ReportText.Ok(await reports.GetGateOutcomesAsync(q, ct));
            var violations = ReportText.Ok(await reports.GetViolationBreakdownAsync(q, ct));

            var incidentsReported = await db.Incidents
                .CountAsync(i => i.CreatedAt >= period.StartUtc && i.CreatedAt < period.EndUtc
                              && i.Status != IncidentStatus.Withdrawn, ct);

            var busiest = hours.Points.OrderByDescending(p => p.Count).FirstOrDefault();
            var hourTotal = hours.Points.Sum(p => p.Count);
            var prev = compare ? summary.Previous : null;

            var usage = new List<KeyFigure>
            {
                new("Total entries", Count(entryExit.TotalEntries),
                    prev is null ? null : Change(entryExit.TotalEntries, prev.SessionsInPeriod, period.Days)),
                new("Visitor entries", Count(entryExit.TotalVisitorEntries)),
                new("Most cars at once", $"{peak.Peak} of {peak.Capacity}",
                    peak.At is DateTime at ? Stamp(at) : null),
                new("Busiest hour", busiest is { Count: > 0 } ? HourRange(busiest.Hour) : "—",
                    busiest is { Count: > 0 } && hourTotal > 0
                        ? $"{Math.Round(busiest.Count * 100.0 / hourTotal)}% of entries" : null),
            };

            var money = new List<KeyFigure>
            {
                new("Total collected", Money(summary.RevenueCollected),
                    prev is null ? null : Change(summary.RevenueCollected, prev.RevenueCollected, period.Days)),
                new("Parking fees", Money(summary.FeesCollected)),
                new("Fines", Money(summary.FinesCollected)),
                new("Unpaid right now", Money(summary.RevenuePending), "all periods, at time of printing"),
            };

            var enforcement = new List<KeyFigure>
            {
                new("Violations issued", Count(summary.ViolationsIssued),
                    prev is null ? null : Change(summary.ViolationsIssued, prev.ViolationsIssued, period.Days)),
                new("Incidents reported", Count(incidentsReported)),
                new("Incidents still open", Count(summary.OpenIncidents), "right now"),
                new("Refused at the gate", Count(gate.UnknownCard + gate.PlateMismatch), "needing a look"),
            };

            var granularity = period.Granularity;
            var entryBars = entryExit.Points
                .Select(p => (Bucket(DateOnly.FromDateTime(p.Date), granularity), (double)p.Entries, Count(p.Entries)))
                .ToList();

            var activeHours = hours.Points.Where(p => p.Count > 0).Select(p => p.Hour).ToList();
            List<(string, double, string)> hourBars = activeHours.Count == 0
                ? []
                : hours.Points
                    .Where(p => p.Hour >= activeHours.Min() && p.Hour <= activeHours.Max())
                    .Select(p => (HourRange(p.Hour), (double)p.Count, Count(p.Count)))
                    .ToList();

            return new ReportContent(
                Title: "Parking summary report",
                FileStem: "parking-summary",
                SecondSignatureCaption: "Noted by",
                PeriodText: $"Period: {Period(period.First, period.Last)}",
                From: period.First,
                To: period.Last,
                KeyFigures:
                [
                    usage[0], usage[2], money[0], money[1], money[2], enforcement[0]
                ],
                Body: col =>
                {
                    Section(col, "Usage");
                    Figures(col, usage);

                    Section(col, granularity switch
                    {
                        ReportGranularity.Week => "Entries per week",
                        ReportGranularity.Month => "Entries per month",
                        _ => "Entries per day"
                    });
                    Bars(col, entryBars);
                    if (entryExit.StillOpen > 0)
                        Note(col, $"{Plural(entryExit.StillOpen, "session", "sessions")} from this period have no exit recorded: cars still inside, or an exit that was not tapped.");

                    Section(col, "Busiest hours", "entries by hour of arrival");
                    if (hourBars.Count == 0) Note(col, "No entries in this period.");
                    else Bars(col, hourBars);

                    Section(col, "Money");
                    Figures(col, money);
                    Note(col, "Collected is counted on the day it was paid. Fees and fines are kept apart.");

                    Section(col, "Gate");
                    Pairs(col,
                    [
                        ("Let in", Count(gate.Entered)),
                        ("Let out", Count(gate.Exited)),
                        ("Refused: card not registered to anyone", Count(gate.UnknownCard)),
                        ("Refused: plate does not match the card holder", Count(gate.PlateMismatch)),
                        ("Refused: routine (lot full, double tap, no camera reading)", Count(gate.RoutineRefusals)),
                    ]);

                    Section(col, "Violations and incidents");
                    Figures(col, enforcement);
                    if (violations.ByStatus.Count > 0)
                    {
                        Pairs(col, violations.ByStatus
                            .OrderByDescending(s => s.Count)
                            .Select(s => (Enum.TryParse<ViolationStatus>(s.Status, out var st) ? ReportText.ViolationStatus(st) : s.Status, Count(s.Count))));
                    }
                    Table(col, ["Most broken rules", ">Violations"], [4, 1],
                        violations.ByRule.Select(r => new[] { r.RuleTitle, Count(r.Count) }),
                        empty: "No violations were issued in this period.");
                });
        }

        private static string HourRange(int hour) => $"{Hour(hour)}–{Hour((hour + 1) % 24)}";

        private static string Hour(int hour) => hour switch
        {
            0 => "12 AM",
            12 => "12 PM",
            < 12 => $"{hour} AM",
            _ => $"{hour - 12} PM"
        };

        private static string Bucket(DateOnly day, ReportGranularity g) => g switch
        {
            ReportGranularity.Week => "Wk of " + day.ToString("MMM d"),
            ReportGranularity.Month => day.ToString("MMM yyyy"),
            _ => day.ToString("ddd, MMM d")
        };
    }
}
