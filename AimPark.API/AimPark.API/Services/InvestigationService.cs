using System.Linq.Expressions;
using AimPark.API.Controllers;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class InvestigationService : IInvestigationService
    {
        /// <summary>How many of each kind the search lists. It is a pick-list, not a report.</summary>
        private const int PerKind = 5;

        /// <summary>How many rows each list in a profile shows. The totals say how many more there are.</summary>
        private const int Latest = 10;
        private const int LatestTaps = 20;

        private readonly AppDbContext _db;

        public InvestigationService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<SearchResponse> SearchAsync(string? typed, CancellationToken ct)
        {
            var term = SearchTerm.Parse(typed);
            var results = new List<SearchResult>();
            if (term.IsEmpty)
                return new SearchResponse(results);

            var like = $"%{term.Text}%";
            var plateLike = $"%{term.Plate}%";

            // People. Archived accounts are included: somebody can be gone and
            // still be the one the question is about.
            var people = await _db.Set<User>().AsNoTracking()
                .Where(u =>
                    (term.UsableText && (
                        EF.Functions.ILike(u.FullName, like) ||
                        EF.Functions.ILike(u.Email, like) ||
                        (u.StudentNumber != null && EF.Functions.ILike(u.StudentNumber, like)))) ||
                    (term.UsableTag && u.RfidTagId != null && u.RfidTagId.Contains(term.Tag)) ||
                    (term.UsablePlate && _db.Set<Vehicle>().Any(v =>
                        v.UserId == u.Id && EF.Functions.ILike(v.PlateNumber, plateLike))))
                .OrderBy(u => u.FullName)
                .Take(PerKind)
                .Select(u => new
                {
                    u.Id, u.FullName, u.Role, u.Affiliation, u.RfidTagId, u.IsDeleted
                })
                .ToListAsync(ct);

            var ids = people.Select(p => p.Id).ToList();
            var plates = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => ids.Contains(v.UserId))
                .Select(v => new { v.UserId, v.PlateNumber })
                .ToListAsync(ct);

            foreach (var p in people)
            {
                var owned = plates.Where(v => v.UserId == p.Id).Select(v => v.PlateNumber).ToList();
                results.Add(new SearchResult(
                    "person", p.FullName,
                    Describe(
                        p.IsDeleted ? "Archived" : Who(p.Role.ToString(), p.Affiliation.ToString()),
                        owned.Count == 0 ? null : string.Join(", ", owned),
                        p.RfidTagId is null ? null : $"card {p.RfidTagId}"),
                    p.Id, null, null, null));
            }

            // Visitors, newest card first.
            var visitors = await _db.Set<VisitorPass>().AsNoTracking()
                .Where(v =>
                    (term.UsableText && EF.Functions.ILike(v.VisitorName, like)) ||
                    (term.UsablePlate && EF.Functions.ILike(v.PlateNumber, plateLike)) ||
                    (term.UsableTag && v.RfidTagId.Contains(term.Tag)))
                .OrderByDescending(v => v.IssuedAt)
                .Take(PerKind)
                .Select(v => new { v.Id, v.VisitorName, v.PlateNumber, v.RfidTagId, v.IssuedAt })
                .ToListAsync(ct);

            foreach (var v in visitors)
                results.Add(new SearchResult(
                    "visitor", v.VisitorName,
                    Describe("Visitor", v.PlateNumber, $"card {v.RfidTagId}"),
                    null, v.Id, null, null));

            // A card that was tapped and belongs to nobody.
            if (term.UsableTag)
            {
                var cards = await _db.Set<GateTapEvent>().AsNoTracking()
                    .Where(t => t.PersonKind == GateTapPersonKind.Unknown
                             && t.RfidTagId != null && t.RfidTagId.Contains(term.Tag))
                    .GroupBy(t => t.RfidTagId!)
                    .Select(g => new { Card = g.Key, Last = g.Max(t => t.At), Taps = g.Count() })
                    .OrderByDescending(c => c.Last)
                    .Take(PerKind)
                    .ToListAsync(ct);

                var held = await HeldCardsAsync(cards.Select(c => c.Card).ToList(), ct);
                foreach (var c in cards.Where(c => !held.Contains(c.Card)))
                    results.Add(new SearchResult(
                        "card", c.Card,
                        $"Card nobody holds · {Taps(c.Taps)}, last {c.Last:MMM d}",
                        null, null, c.Card, null));
            }

            // A plate the camera read that nobody registered.
            if (term.UsablePlate)
            {
                var seen = await _db.Set<GateTapEvent>().AsNoTracking()
                    .Where(t => t.CameraPlate != null && EF.Functions.ILike(t.CameraPlate, plateLike))
                    .GroupBy(t => t.CameraPlate!)
                    .Select(g => new { Plate = g.Key, Last = g.Max(t => t.At), Taps = g.Count() })
                    .OrderByDescending(c => c.Last)
                    .Take(PerKind)
                    .ToListAsync(ct);

                var known = await KnownPlatesAsync(seen.Select(s => s.Plate).ToList(), ct);
                foreach (var s in seen.Where(s => !known.Contains(s.Plate)))
                    results.Add(new SearchResult(
                        "plate", s.Plate,
                        $"Plate not registered · {Taps(s.Taps)}, last {s.Last:MMM d}",
                        null, null, null, s.Plate));
            }

            return new SearchResponse(results);
        }

        public async Task<InvestigationProfile?> ProfileAsync(
            Guid? userId, Guid? visitorPassId, string? card, string? plate, CancellationToken ct)
        {
            if (userId is Guid uid)
            {
                var user = await _db.Set<User>().AsNoTracking().FirstOrDefaultAsync(u => u.Id == uid, ct);
                return user is null ? null : await ForPersonAsync(user, ct);
            }

            if (visitorPassId is Guid pid)
            {
                var pass = await _db.Set<VisitorPass>().AsNoTracking().FirstOrDefaultAsync(p => p.Id == pid, ct);
                return pass is null ? null : await ForVisitorAsync(pass, ct);
            }

            var tag = RfidTag.Normalize(card);
            if (tag.Length > 0)
            {
                // Whoever holds the card now. A card handed from one person to
                // another has taps under both; the profile is the holder's.
                var holder = await _db.Set<User>().AsNoTracking()
                    .Where(u => u.RfidTagId == tag)
                    .OrderBy(u => u.IsDeleted)
                    .FirstOrDefaultAsync(ct);
                if (holder is not null)
                    return await ForPersonAsync(holder, ct);

                var pass = await _db.Set<VisitorPass>().AsNoTracking()
                    .Where(p => p.RfidTagId == tag)
                    .OrderByDescending(p => p.IssuedAt)
                    .FirstOrDefaultAsync(ct);
                if (pass is not null)
                    return await ForVisitorAsync(pass, ct);

                return await ForUnknownCardAsync(tag, ct);
            }

            var squashed = IdentifierNormalizer.NormalizePlate(plate);
            if (squashed.Length > 0)
            {
                var owner = await _db.Set<Vehicle>().AsNoTracking()
                    .Where(v => v.PlateNumber == squashed)
                    .Select(v => v.User)
                    .FirstOrDefaultAsync(ct);
                if (owner is not null)
                    return await ForPersonAsync(owner, ct);

                var pass = await _db.Set<VisitorPass>().AsNoTracking()
                    .Where(p => p.PlateNumber == squashed)
                    .OrderByDescending(p => p.IssuedAt)
                    .FirstOrDefaultAsync(ct);
                if (pass is not null)
                    return await ForVisitorAsync(pass, ct);

                return await ForUnregisteredPlateAsync(squashed, ct);
            }

            return null;
        }

        private async Task<InvestigationProfile> ForPersonAsync(User user, CancellationToken ct)
        {
            var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == user.Id)
                .OrderBy(v => v.CreatedAt)
                .ToListAsync(ct);

            var plates = vehicles.Select(v => v.PlateNumber).ToList();
            var card = user.RfidTagId;

            // Their card, or their car on anyone's card: the second is how a
            // borrowed card shows up.
            Expression<Func<GateTapEvent, bool>> taps = t =>
                t.UserId == user.Id ||
                (card != null && t.RfidTagId == card) ||
                (t.CameraPlate != null && plates.Contains(t.CameraPlate));

            var profile = new InvestigationProfile
            {
                Kind = "person",
                Title = user.FullName,
                Subtitle = Describe(
                    user.IsDeleted ? "Archived" : Who(user.Role.ToString(), user.Affiliation.ToString()),
                    user.Email, null),
                Person = new ProfilePerson(
                    user.Id, user.FullName, user.Email, user.Role.ToString(), user.Affiliation.ToString(),
                    user.StudentNumber, user.AccountStatus.ToString(), user.RfidTagId, user.RfidStatus.ToString(),
                    user.IsDeleted,
                    [.. vehicles.Select(v => new ProfileVehicle(v.PlateNumber, v.VehicleType.ToString(), v.Color))])
            };

            await FillTapsAsync(profile, taps, ct);
            await FillSessionsAsync(profile, l => l.UserId == user.Id, ct);

            var violations = await _db.Set<Violation>().AsNoTracking()
                .Where(v => v.UserId == user.Id)
                .OrderByDescending(v => v.CreatedAt)
                .Select(v => new { v.Id, v.PolicyRule.Title, v.Status, v.PenaltyAmount, v.CreatedAt })
                .ToListAsync(ct);
            profile.Violations =
                [.. violations.Take(Latest).Select(v => new ProfileViolation(
                    v.Id, v.Title, v.Status.ToString(), v.PenaltyAmount, v.CreatedAt))];

            var incidents = await _db.Set<Incident>().AsNoTracking()
                .Where(i => i.ReportedByUserId == user.Id)
                .OrderByDescending(i => i.CreatedAt)
                .Select(i => new { i.Id, i.Category, i.Status, i.CreatedAt, i.Description })
                .ToListAsync(ct);
            profile.Incidents =
                [.. incidents.Take(Latest).Select(i => new ProfileIncident(
                    i.Id, i.Category.ToString(), i.Status.ToString(), i.CreatedAt, Preview(i.Description)))];

            profile.Totals = profile.Totals with { Violations = violations.Count, Incidents = incidents.Count };
            return profile;
        }

        private async Task<InvestigationProfile> ForVisitorAsync(VisitorPass pass, CancellationToken ct)
        {
            Expression<Func<GateTapEvent, bool>> taps = t =>
                t.VisitorPassId == pass.Id ||
                (t.CameraPlate != null && t.CameraPlate == pass.PlateNumber);

            var profile = new InvestigationProfile
            {
                Kind = "visitor",
                Title = pass.VisitorName,
                Subtitle = Describe("Visitor", pass.PlateNumber, $"card {pass.RfidTagId}"),
                Visitor = new ProfileVisitor(
                    pass.Id, pass.VisitorName, pass.PlateNumber, pass.RfidTagId, pass.Purpose,
                    pass.IssuedAt, pass.ExpiresAt, pass.ReturnedAt)
            };

            await FillTapsAsync(profile, taps, ct);
            await FillSessionsAsync(profile, l => l.VisitorPassId == pass.Id, ct);
            return profile;
        }

        private async Task<InvestigationProfile?> ForUnknownCardAsync(string tag, CancellationToken ct)
        {
            Expression<Func<GateTapEvent, bool>> taps = t => t.RfidTagId == tag;

            var profile = new InvestigationProfile
            {
                Kind = "card",
                Title = tag,
                Subtitle = "Card nobody holds",
                Card = tag
            };

            await FillTapsAsync(profile, taps, ct);
            // A card that never reached a reader is not something we know of.
            return profile.Totals.Taps == 0 ? null : profile;
        }

        private async Task<InvestigationProfile?> ForUnregisteredPlateAsync(string plate, CancellationToken ct)
        {
            Expression<Func<GateTapEvent, bool>> taps = t => t.CameraPlate == plate;

            var profile = new InvestigationProfile
            {
                Kind = "plate",
                Title = plate,
                Subtitle = "Plate not registered",
                Plate = plate
            };

            await FillTapsAsync(profile, taps, ct);
            await FillSessionsAsync(profile, l => l.AlprPlateNumber == plate, ct);
            return profile.Totals.Taps == 0 && profile.Totals.Sessions == 0 ? null : profile;
        }

        private async Task FillTapsAsync(
            InvestigationProfile profile, Expression<Func<GateTapEvent, bool>> match, CancellationToken ct)
        {
            var scope = _db.Set<GateTapEvent>().AsNoTracking().Where(match);

            // Same "serious" rule as the Gate Taps page (LiveGateController.AsRow).
            var counts = await scope
                .GroupBy(_ => 1)
                .Select(g => new
                {
                    Total = g.Count(),
                    Denied = g.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Manual),
                    Serious = g.Count(t => !t.Opened && t.PersonKind != GateTapPersonKind.Manual
                        && (t.PersonKind == GateTapPersonKind.Unknown || t.PlateMatches == false))
                })
                .FirstOrDefaultAsync(ct);

            profile.Taps = await scope
                .OrderByDescending(t => t.At)
                .Take(LatestTaps)
                .Select(LiveGateController.AsRow)
                .ToListAsync(ct);

            profile.Totals = profile.Totals with
            {
                Taps = counts?.Total ?? 0,
                DeniedTaps = counts?.Denied ?? 0,
                SeriousDeniedTaps = counts?.Serious ?? 0
            };
        }

        private async Task FillSessionsAsync(
            InvestigationProfile profile, Expression<Func<ParkingLog, bool>> match, CancellationToken ct)
        {
            var scope = _db.Set<ParkingLog>().AsNoTracking().Where(match);

            profile.Sessions = await scope
                .OrderByDescending(l => l.EntryTime)
                .Take(Latest)
                .Select(l => new ProfileSession(l.Id, l.EntryTime, l.ExitTime, l.Gate, l.AlprPlateNumber, l.AlprMatched,
                    l.Slot != null ? l.Slot.SlotCode : null, l.SlotConfirmedAt != null))
                .ToListAsync(ct);

            profile.Totals = profile.Totals with { Sessions = await scope.CountAsync(ct) };
        }

        // Which of these cards does somebody hold, or has a visitor been lent.
        private async Task<HashSet<string>> HeldCardsAsync(List<string> cards, CancellationToken ct)
        {
            var users = await _db.Set<User>().AsNoTracking()
                .Where(u => u.RfidTagId != null && cards.Contains(u.RfidTagId))
                .Select(u => u.RfidTagId!)
                .ToListAsync(ct);
            var passes = await _db.Set<VisitorPass>().AsNoTracking()
                .Where(p => cards.Contains(p.RfidTagId))
                .Select(p => p.RfidTagId)
                .ToListAsync(ct);
            return [.. users, .. passes];
        }

        // Which of these plates a vehicle or a visitor pass already carries.
        private async Task<HashSet<string>> KnownPlatesAsync(List<string> plates, CancellationToken ct)
        {
            var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                .Where(v => plates.Contains(v.PlateNumber))
                .Select(v => v.PlateNumber)
                .ToListAsync(ct);
            var passes = await _db.Set<VisitorPass>().AsNoTracking()
                .Where(p => plates.Contains(p.PlateNumber))
                .Select(p => p.PlateNumber)
                .ToListAsync(ct);
            return [.. vehicles, .. passes];
        }

        private static string Who(string role, string affiliation) =>
            role == "User" ? affiliation : role;

        private static string Describe(string first, string? second, string? third) =>
            string.Join(" · ", new[] { first, second, third }.Where(s => !string.IsNullOrWhiteSpace(s)));

        private static string Taps(int count) => count == 1 ? "1 tap" : $"{count} taps";

        private static string Preview(string text)
        {
            var oneLine = string.Join(' ', text.Split((char[]?)null, StringSplitOptions.RemoveEmptyEntries));
            return oneLine.Length <= 120 ? oneLine : oneLine[..117] + "...";
        }
    }
}
