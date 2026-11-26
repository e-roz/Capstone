using AimPark.API.Data;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using Microsoft.EntityFrameworkCore;
using static AimPark.API.Reports.PdfLayout;

namespace AimPark.API.Reports
{
    /// <summary>
    /// Report 6, for the admin office: who is registered, with what, who is
    /// waiting, and whose licence or OR is about to run out.
    /// </summary>
    /// <remarks>
    /// A snapshot "as of" the moment it is printed, not a period: a list of
    /// registered vehicles is true now, not "during November". The period the
    /// page has picked is ignored.
    /// </remarks>
    public class VehiclesReport(AppDbContext db) : IPdfReport
    {
        /// <summary>How far ahead "expiring soon" looks.</summary>
        public const int SoonDays = 30;

        public string Kind => "vehicles";

        public async Task<ReportContent> BuildAsync(ReportQuery query, CancellationToken ct)
        {
            var now = DateTime.UtcNow;
            var today = PhilippineTime.Today();
            var soon = now.AddDays(SoonDays);

            var active = db.Users.AsNoTracking()
                .Where(u => !u.IsDeleted && u.Role == UserRole.User && u.AccountStatus == AccountStatus.Active);

            var activeCount = await active.CountAsync(ct);

            var vehicles = await db.vehicles.AsNoTracking()
                .Where(v => !v.User.IsDeleted && v.User.Role == UserRole.User && v.User.AccountStatus == AccountStatus.Active)
                .Select(v => new
                {
                    v.PlateNumber,
                    v.VehicleType,
                    v.IsEBike,
                    v.RegistrationValidThrough,
                    Owner = v.User.FullName,
                    v.User.Affiliation
                })
                .ToListAsync(ct);

            var pending = await db.Users.AsNoTracking()
                .Where(u => !u.IsDeleted && u.RegistrationStep == RegistrationStep.Completed
                         && u.AccountStatus == AccountStatus.PendingReview)
                .OrderBy(u => u.UpdatedAt)
                .Select(u => new { u.FullName, u.Affiliation, u.UpdatedAt, u.IsEBikeApplicant, Retake = u.DocumentRetakeJson != null })
                .ToListAsync(ct);

            var licences = await active
                .Where(u => u.LicenseValidThrough != null && u.LicenseValidThrough < soon)
                .OrderBy(u => u.LicenseValidThrough)
                .Select(u => new { u.FullName, u.Affiliation, Through = u.LicenseValidThrough!.Value })
                .ToListAsync(ct);

            var receipts = vehicles
                .Where(v => !v.IsEBike && v.RegistrationValidThrough is DateTime d && d < soon)
                .OrderBy(v => v.RegistrationValidThrough)
                .ToList();

            var renewalsWaiting = await db.DocumentRenewals.CountAsync(r => r.Status == RenewalStatus.Pending, ct);

            var cards = await active
                .GroupBy(u => u.RfidStatus)
                .Select(g => new { g.Key, Count = g.Count() })
                .ToDictionaryAsync(x => x.Key, x => x.Count, ct);

            string TypeLabel(VehicleType t, bool ebike) => ebike ? "E-bike" : ReportText.Humanize(t);
            string Expiry(DateTime through) =>
                through < now ? $"Expired {Date(through)}"
                : $"{Date(through)} (in {(PhilippineTime.LocalDate(through).DayNumber - today.DayNumber)} days)";

            var licencesExpired = licences.Count(l => l.Through < now);
            var receiptsExpired = receipts.Count(r => r.RegistrationValidThrough < now);

            var figures = new List<KeyFigure>
            {
                new("Active users", Count(activeCount)),
                new("Registered vehicles", Count(vehicles.Count)),
                new("Applications waiting", Count(pending.Count)),
                new("Renewals waiting", Count(renewalsWaiting)),
                new("Licences expired", Count(licencesExpired), $"{licences.Count - licencesExpired} more within {SoonDays} days"),
                new("ORs expired", Count(receiptsExpired), $"{receipts.Count - receiptsExpired} more within {SoonDays} days"),
                new("Cards suspended", Count(cards.GetValueOrDefault(RfidStatus.Suspended))),
                new("Cards revoked", Count(cards.GetValueOrDefault(RfidStatus.Revoked))),
            };

            var affiliations = Enum.GetValues<Affiliation>();
            var types = new[] { "Car", "Motorcycle", "E-bike" };
            var grid = affiliations
                .Select(a =>
                {
                    var mine = vehicles.Where(v => v.Affiliation == a).ToList();
                    var row = new List<string> { a.ToString() };
                    row.AddRange(types.Select(t => Count(mine.Count(v => TypeLabel(v.VehicleType, v.IsEBike) == t))));
                    row.Add(Count(mine.Count));
                    return row.ToArray();
                })
                .ToList();

            return new ReportContent(
                Title: "Registered vehicles report",
                FileStem: "registered-vehicles",
                SecondSignatureCaption: "Noted by (Admin Office)",
                PeriodText: $"As of {Stamp(now)}",
                From: null,
                To: null,
                KeyFigures: figures.Take(6).ToList(),
                Body: col =>
                {
                    Figures(col, figures);

                    Section(col, "Registered vehicles", "active accounts only");
                    Table(col, ["", ">Car", ">Motorcycle", ">E-bike", ">Total"], [2, 1, 1, 1, 1], grid,
                        totalRow:
                        [
                            "Total",
                            .. types.Select(t => Count(vehicles.Count(v => TypeLabel(v.VehicleType, v.IsEBike) == t))),
                            Count(vehicles.Count)
                        ]);

                    Section(col, "Applications waiting for review", "oldest first");
                    Table(col, ["Name", "Affiliation", "Vehicle", "Waiting since", "Note"], [2.6f, 1.1f, 1, 1.4f, 2],
                        pending.Select(p => new[]
                        {
                            p.FullName,
                            p.Affiliation.ToString(),
                            p.IsEBikeApplicant ? "E-bike" : "Car / motorcycle",
                            Date(p.UpdatedAt),
                            p.Retake ? "Asked to retake a document" : p.IsEBikeApplicant ? "Needs in-person inspection" : ""
                        }),
                        empty: "No applications are waiting.");

                    Section(col, "Driver's licences expired or expiring", $"within {SoonDays} days");
                    Table(col, ["Name", "Affiliation", "Valid through"], [3, 1.2f, 2.4f],
                        licences.Select(l => new[] { l.FullName, l.Affiliation.ToString(), Expiry(l.Through) }),
                        empty: $"No licence runs out in the next {SoonDays} days.");

                    Section(col, "Vehicle registrations (OR) expired or expiring", $"within {SoonDays} days");
                    Table(col, ["Plate", "Type", "Owner", "Valid through"], [1.2f, 1.1f, 2.6f, 2.4f],
                        receipts.Select(r => new[]
                        {
                            r.PlateNumber,
                            TypeLabel(r.VehicleType, r.IsEBike),
                            r.Owner,
                            Expiry(r.RegistrationValidThrough!.Value)
                        }),
                        empty: $"No vehicle registration runs out in the next {SoonDays} days.");
                    Note(col, "E-bikes are not LTO-registered and have no OR to expire.");
                });
        }
    }
}
