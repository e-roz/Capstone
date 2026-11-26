using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 4, for security: who came in and out, when, in what, and who was
    /// turned away. Pulled when something happened and someone asks "who was
    /// inside on the 20th at three?".
    /// </summary>
    public class EntryExitReport(IReportService reports, AppDbContext db) : IPdfReport
    {
        /// <summary>A week of a busy lot is already a long printout; a month is a phone book.</summary>
        public const int MaxDays = 7;

        public string Kind => "entry-exit";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var period = await reports.ResolvePeriodAsync(query, ct);
            if (period.Days > MaxDays)
                throw new ReportRequestException(
                    $"The entry/exit log covers at most {MaxDays} days. Pick a single day or a range of {MaxDays} days or fewer.");

            var sessions = await db.ParkingLogs.AsNoTracking()
                .Where(l => l.EntryTime >= period.StartUtc && l.EntryTime < period.EndUtc)
                .OrderBy(l => l.EntryTime)
                .Select(l => new
                {
                    l.EntryTime,
                    l.ExitTime,
                    UserName = l.User != null ? l.User.FullName : null,
                    VisitorName = l.VisitorPass != null ? l.VisitorPass.VisitorName : null,
                    VisitorPlate = l.VisitorPass != null ? l.VisitorPass.PlateNumber : null,
                    l.AlprPlateNumber,
                    l.VehicleType,
                    l.Gate,
                    Bay = l.Slot != null ? l.Slot.SlotCode : null,
                    Confirmed = l.SlotConfirmedAt != null
                })
                .ToListAsync(ct);

            var exits = await db.ParkingLogs
                .CountAsync(l => l.ExitTime != null && l.ExitTime >= period.StartUtc && l.ExitTime < period.EndUtc, ct);

            var refused = await db.GateTapEvents.AsNoTracking()
                .Where(t => t.At >= period.StartUtc && t.At < period.EndUtc
                         && !t.Opened && t.PersonKind != GateTapPersonKind.Manual)
                .OrderBy(t => t.At)
                .Select(t => new { t.At, t.Gate, t.Direction, t.PersonName, t.PersonKind, t.CameraPlate, t.PlateMatches, t.Message })
                .ToListAsync(ct);

            bool Serious(string kind, bool? matches) => kind == GateTapPersonKind.Unknown || matches == false;
            var serious = refused.Count(t => Serious(t.PersonKind, t.PlateMatches));
            var visitors = sessions.Count(s => s.VisitorName is not null);

            var figures = new List<KeyFigure>
            {
                new("Entries", Count(sessions.Count)),
                new("Exits", Count(exits)),
                new("Visitor entries", Count(visitors)),
                new("Refused at the gate", Count(refused.Count), $"{serious} needing a look"),
            };

            return new ReportContent(
                Title: "Entry and exit log",
                FileStem: "entry-exit-log",
                SecondSignatureCaption: "Noted by (Security)",
                PeriodText: $"Period: {Period(period.First, period.Last)}",
                From: period.First,
                To: period.Last,
                KeyFigures: figures,
                Body: col =>
                {
                    Figures(col, figures);

                    Section(col, "Vehicles that came in", "by time of entry");
                    Table(col,
                        ["Date", "In", "Out", "Name", "Plate", "Type", ">Gate", "Bay", ">Stayed"],
                        [1.1f, 0.9f, 1.3f, 2.3f, 1.1f, 0.9f, 0.5f, 0.8f, 0.9f],
                        sessions.Select(s =>
                        {
                            var name = s.UserName ?? (s.VisitorName is null ? "—" : $"{s.VisitorName} (visitor)");
                            var plate = s.AlprPlateNumber ?? s.VisitorPlate ?? "—";
                            string @out;
                            if (s.ExitTime is not DateTime x) @out = "Still inside";
                            else if (PhilippineTime.LocalDate(x) == PhilippineTime.LocalDate(s.EntryTime)) @out = Time(x);
                            else @out = $"{Local(x):MMM d} {Time(x)}";

                            return new[]
                            {
                                Local(s.EntryTime).ToString("ddd MMM d"),
                                Time(s.EntryTime),
                                @out,
                                name,
                                plate,
                                s.VehicleType is null ? "—" : ReportText.Humanize(s.VehicleType),
                                s.Gate?.ToString() ?? "—",
                                s.Bay is null ? "—" : s.Confirmed ? s.Bay : s.Bay + "*",
                                s.ExitTime is DateTime e ? ReportText.Duration(e - s.EntryTime) : "—"
                            };
                        }),
                        empty: "No vehicles came in during this period.");
                    if (sessions.Any(s => s.Bay is not null && !s.Confirmed))
                        Note(col, "* Bay suggested by the gate; the driver did not confirm it in the app.");

                    Section(col, "Refused at the gate");
                    Table(col,
                        ["Date and time", ">Gate", "Name or card", "Camera read", "Reason"],
                        [1.6f, 0.6f, 2, 1.1f, 3.2f],
                        refused.Select(t => new[]
                        {
                            Short(t.At),
                            $"{t.Gate} {t.Direction}".Trim(),
                            t.PersonName ?? "Unregistered card",
                            t.CameraPlate ?? "—",
                            (Serious(t.PersonKind, t.PlateMatches) ? "[!] " : "") + ReportText.Clip(t.Message, 90)
                        }),
                        empty: "Nobody was refused during this period.");
                    if (serious > 0)
                        Note(col, "[!] Needs a look: a card registered to nobody, or a plate that is not the card holder's.");
                });
        }
    }
}
