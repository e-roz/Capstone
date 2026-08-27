using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Lends spare RFID cards to people with no account, and tells a guard who
    /// any card belongs to.
    /// </summary>
    public class VisitorPassService : IVisitorPassService
    {
        private readonly IRepository<VisitorPass> _passes;
        private readonly AppDbContext _db;

        public VisitorPassService(IRepository<VisitorPass> passes, AppDbContext db)
        {
            _passes = passes;
            _db = db;
        }

        public async Task<ActionResult<VisitorPassResponse>> IssueAsync(
            IssueVisitorPassDto dto, Guid issuedByUserId, CancellationToken ct)
        {
            var tag = dto.RfidTagId?.Trim() ?? string.Empty;
            if (ValidationHelper.HasEmptyFields(tag, dto.VisitorName, dto.PlateNumber))
                return new BadRequestObjectResult(new
                {
                    message = "Card, visitor name and plate number are all required."
                });

            if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType))
                return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

            // A card belonging to a registered user must never be lent out. It
            // would open the barrier as *them*, park in their name, and bill
            // them for it.
            var belongsToUser = await _db.Set<User>()
                .AnyAsync(u => u.RfidTagId == tag && !u.IsDeleted, ct);

            if (belongsToUser)
                return new ConflictObjectResult(new
                {
                    message = "That card is assigned to a registered user. Use a spare visitor card."
                });

            await ExpireStalePassesAsync(ct);

            var alreadyOut = await _passes.ExistsAsync(
                p => p.RfidTagId == tag && p.Status == VisitorPassStatus.Active, ct);

            if (alreadyOut)
                return new ConflictObjectResult(new
                {
                    message = "That card is already out with another visitor. Take it back first, or use a different card."
                });

            var now = DateTime.UtcNow;

            // A pass with no end is a spare card that opens the barrier for
            // ever, which is the one outcome lending cards must not produce.
            var expiresAt = dto.ValidForHours is int hours && hours > 0
                ? now.AddHours(Math.Min(hours, 24 * 7))
                : now.Date.AddDays(1).AddSeconds(-1);

            var pass = new VisitorPass
            {
                Id = Guid.NewGuid(),
                RfidTagId = tag,
                VisitorName = dto.VisitorName.Trim(),
                PlateNumber = IdentifierNormalizer.NormalizePlate(dto.PlateNumber),
                VehicleType = vehicleType,
                Purpose = string.IsNullOrWhiteSpace(dto.Purpose) ? null : dto.Purpose.Trim(),
                ContactNumber = IdentifierNormalizer.NormalizePhone(dto.ContactNumber),
                IssuedByUserId = issuedByUserId,
                IssuedAt = now,
                ExpiresAt = expiresAt,
                Status = VisitorPassStatus.Active,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _passes.AddAsync(pass, ct);
            await _passes.SaveAsync(ct);

            return new OkObjectResult(await MapAsync(pass, ct));
        }

        public async Task<ActionResult<VisitorPassListResponse>> ListAsync(
            string? status, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            await ExpireStalePassesAsync(ct);

            var query = _db.Set<VisitorPass>().AsNoTracking();
            if (!string.IsNullOrWhiteSpace(status)
                && Enum.TryParse<VisitorPassStatus>(status, true, out var parsed))
            {
                query = query.Where(p => p.Status == parsed);
            }

            var totalCount = await query.CountAsync(ct);

            var passes = await query
                .OrderByDescending(p => p.IssuedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .ToListAsync(ct);

            var responses = new List<VisitorPassResponse>(passes.Count);
            foreach (var pass in passes)
                responses.Add(await MapAsync(pass, ct));

            return new OkObjectResult(new VisitorPassListResponse
            {
                Passes = responses,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        public async Task<ActionResult<object>> ReturnAsync(Guid passId, CancellationToken ct)
        {
            var pass = await _passes.FindAsync(p => p.Id == passId, ct);
            if (pass is null)
                return new NotFoundObjectResult(new { message = "Visitor pass not found." });

            if (pass.ReturnedAt is not null)
                return new BadRequestObjectResult(new { message = "That card has already been handed back." });

            // Taking the card back while the car is still in the lot would leave
            // an open session nothing can close: exit is resolved from the card,
            // and the card would be back in the drawer.
            var stillInside = await _db.Set<ParkingLog>()
                .AnyAsync(l => l.VisitorPassId == pass.Id && l.ExitTime == null, ct);

            if (stillInside)
                return new BadRequestObjectResult(new
                {
                    message = "This visitor's vehicle is still inside. Log the exit first, then take the card back."
                });

            pass.ReturnedAt = DateTime.UtcNow;
            pass.Status = VisitorPassStatus.Returned;
            pass.UpdatedAt = DateTime.UtcNow;

            _passes.Update(pass);
            await _passes.SaveAsync(ct);

            return new OkObjectResult(new { message = "Card returned." });
        }

        public async Task<ActionResult<TagLookupResponse>> LookupTagAsync(string rfidTagId, CancellationToken ct)
        {
            var tag = rfidTagId?.Trim() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(tag))
                return new BadRequestObjectResult(new { message = "A card number is required." });

            var nowUtc = DateTime.UtcNow;

            var user = await _db.Set<User>().AsNoTracking()
                .FirstOrDefaultAsync(u => u.RfidTagId == tag && !u.IsDeleted, ct);

            if (user is not null)
            {
                var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                    .Where(v => v.UserId == user.Id)
                    .Select(v => new TagVehicleResponse
                    {
                        PlateNumber = v.PlateNumber,
                        VehicleType = v.VehicleType.ToString(),
                        Color = v.Color,
                        RegistrationExpired = v.RegistrationValidThrough != null
                                              && v.RegistrationValidThrough < nowUtc
                    })
                    .ToListAsync(ct);

                var session = await OpenSessionAsync(l => l.UserId == user.Id, ct);

                var denied =
                    user.AccountStatus != AccountStatus.Active
                        ? "This account is not approved."
                        : RfidAccess.IsSuspendedNow(user, nowUtc)
                            ? "RFID access is suspended."
                            : user.RfidStatus == RfidStatus.Unassigned
                                ? "No card is assigned to this account."
                                : null;

                return new OkObjectResult(new TagLookupResponse
                {
                    Holder = "User",
                    Name = user.FullName,
                    Affiliation = user.Affiliation.ToString(),
                    Vehicles = vehicles,
                    AccessAllowed = denied is null,
                    DeniedReason = denied,
                    IsInside = session is not null,
                    SlotCode = session?.SlotCode,
                    EntryTime = session?.EntryTime
                });
            }

            await ExpireStalePassesAsync(ct);

            var pass = await _db.Set<VisitorPass>().AsNoTracking()
                .Where(p => p.RfidTagId == tag)
                .OrderByDescending(p => p.IssuedAt)
                .FirstOrDefaultAsync(ct);

            if (pass is null)
                return new OkObjectResult(new TagLookupResponse
                {
                    Holder = "Unknown",
                    AccessAllowed = false,
                    DeniedReason = "This card is not registered to anyone."
                });

            var passSession = await OpenSessionAsync(l => l.VisitorPassId == pass.Id, ct);

            var passDenied = pass.Status switch
            {
                VisitorPassStatus.Returned => "This card was handed back and is no longer in use.",
                VisitorPassStatus.Expired => "This visitor pass has expired.",
                _ when pass.ExpiresAt <= nowUtc => "This visitor pass has expired.",
                _ => null
            };

            return new OkObjectResult(new TagLookupResponse
            {
                Holder = "Visitor",
                Name = pass.VisitorName,
                Affiliation = "Visitor",
                Vehicles =
                [
                    new TagVehicleResponse
                    {
                        PlateNumber = pass.PlateNumber,
                        VehicleType = pass.VehicleType.ToString()
                    }
                ],
                AccessAllowed = passDenied is null,
                DeniedReason = passDenied,
                IsInside = passSession is not null,
                SlotCode = passSession?.SlotCode,
                EntryTime = passSession?.EntryTime,
                PassExpiresAt = pass.ExpiresAt
            });
        }

        /// <summary>
        /// Closes out passes whose day has ended.
        /// </summary>
        /// <remarks>
        /// Done lazily on read rather than by a scheduled job, matching how
        /// expired RFID suspensions are handled. Nothing here needs to happen at
        /// the stroke of midnight — it needs to be true by the time anybody
        /// looks, and every path that could look calls this first.
        ///
        /// A card that is still out stays visible as Expired rather than
        /// Returned. The guard is missing a card, and the list is where they
        /// find that out.
        /// </remarks>
        private async Task ExpireStalePassesAsync(CancellationToken ct)
        {
            var now = DateTime.UtcNow;

            var stale = await _db.Set<VisitorPass>()
                .Where(p => p.Status == VisitorPassStatus.Active && p.ExpiresAt <= now)
                .ToListAsync(ct);

            if (stale.Count == 0) return;

            foreach (var pass in stale)
            {
                pass.Status = VisitorPassStatus.Expired;
                pass.UpdatedAt = now;
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task<OpenSession?> OpenSessionAsync(
            System.Linq.Expressions.Expression<Func<ParkingLog, bool>> match,
            CancellationToken ct)
            => await _db.Set<ParkingLog>().AsNoTracking()
                .Where(match)
                .Where(l => l.ExitTime == null)
                .Select(l => new OpenSession(
                    l.Slot != null ? l.Slot.SlotCode : null,
                    l.EntryTime))
                .FirstOrDefaultAsync(ct);

        /// <summary>A session that has not been closed yet.</summary>
        private sealed record OpenSession(string? SlotCode, DateTime EntryTime);

        private async Task<VisitorPassResponse> MapAsync(VisitorPass pass, CancellationToken ct)
        {
            var session = await OpenSessionAsync(l => l.VisitorPassId == pass.Id, ct);

            var issuedBy = await _db.Set<User>().AsNoTracking()
                .Where(u => u.Id == pass.IssuedByUserId)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);

            return new VisitorPassResponse
            {
                PassId = pass.Id,
                RfidTagId = pass.RfidTagId,
                VisitorName = pass.VisitorName,
                PlateNumber = pass.PlateNumber,
                VehicleType = pass.VehicleType.ToString(),
                Purpose = pass.Purpose,
                ContactNumber = pass.ContactNumber,
                Status = pass.Status.ToString(),
                IssuedAt = pass.IssuedAt,
                ExpiresAt = pass.ExpiresAt,
                ReturnedAt = pass.ReturnedAt,
                IssuedByName = issuedBy,
                IsInside = session is not null,
                SlotCode = session?.SlotCode
            };
        }
    }
}
