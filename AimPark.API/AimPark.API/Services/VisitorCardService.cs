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
    /// The guard post's drawer of visitor cards: which cards are in it, and
    /// where each one is right now.
    /// </summary>
    public class VisitorCardService : IVisitorCardService
    {
        private readonly AppDbContext _db;

        public VisitorCardService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ActionResult<List<VisitorCardResponse>>> ListAsync(CancellationToken ct)
        {
            var cards = await _db.Set<VisitorCard>().AsNoTracking()
                .OrderBy(c => c.Label)
                .ToListAsync(ct);

            var tags = cards.Select(c => c.RfidTagId).ToList();
            var passes = await _db.Set<VisitorPass>().AsNoTracking()
                .Where(p => tags.Contains(p.RfidTagId))
                .Select(p => new
                {
                    p.Id, p.RfidTagId, p.VisitorName, p.PlateNumber, p.IssuedAt,
                    p.ReturnedAt, p.CardCollectedAt, p.Status
                })
                .ToListAsync(ct);

            var byTag = passes.GroupBy(p => p.RfidTagId).ToDictionary(g => g.Key, g => g.ToList());

            return new OkObjectResult(cards.Select(card =>
            {
                var lent = byTag.GetValueOrDefault(card.RfidTagId) ?? [];
                var last = lent.OrderByDescending(p => p.IssuedAt).FirstOrDefault();

                return new VisitorCardResponse
                {
                    RfidTagId = card.RfidTagId,
                    Label = card.Label,
                    Whereabouts = WhereIs(last?.ReturnedAt, last is not null),
                    LastPassId = last?.Id,
                    LastVisitorName = last?.VisitorName,
                    LastPlateNumber = last?.PlateNumber,
                    LastIssuedAt = last?.IssuedAt,
                    LastReturnedAt = last?.ReturnedAt,
                    TimesLent = lent.Count,
                    CreatedAt = card.CreatedAt
                };
            }).ToList());
        }

        /// <summary>
        /// Read off the last pass on the card. A pass that hasn't ended still
        /// has the card out with its visitor; once the visitor has left, the
        /// card is free to lend again.
        /// </summary>
        private static string WhereIs(DateTime? returnedAt, bool everLent) =>
            everLent && returnedAt is null ? "OutWithVisitor" : "InDrawer";

        public async Task<ActionResult<VisitorCardResponse>> AddAsync(AddVisitorCardDto dto, CancellationToken ct)
        {
            var tag = RfidTag.Normalize(dto.RfidTagId);
            if (!RfidTag.LooksValid(tag))
                return new BadRequestObjectResult(new { message = "Tap the card on the reader, or type its UID." });

            var label = dto.Label?.Trim().ToUpperInvariant() ?? string.Empty;
            if (label.Length is 0 or > 20)
                return new BadRequestObjectResult(new
                {
                    message = "Give the card a short label, the same as what is written on it (e.g. V1)."
                });

            if (await _db.Set<VisitorCard>().AnyAsync(c => c.RfidTagId == tag, ct))
                return new ConflictObjectResult(new { message = "That card is already a visitor card." });

            if (await _db.Set<VisitorCard>().AnyAsync(c => c.Label == label, ct))
                return new ConflictObjectResult(new { message = $"Another visitor card is already labelled {label}." });

            // A visitor card must never also open the gate as somebody.
            var holder = await _db.Set<User>().AsNoTracking()
                .Where(u => u.RfidTagId == tag && !u.IsDeleted)
                .Select(u => u.FullName)
                .FirstOrDefaultAsync(ct);
            if (holder is not null)
                return new ConflictObjectResult(new
                {
                    message = $"That card is assigned to {holder}. Revoke it from them first, or use another card."
                });

            var revoked = await _db.Set<RfidCard>().FindAsync([tag], ct);
            if (revoked is not null && revoked.State == RfidCardState.Blocked)
                return new ConflictObjectResult(new
                {
                    message = $"That card was reported {revoked.Reason.ToString().ToLowerInvariant()} and cannot be used again."
                });

            // A free card from the revoked pool moving into the visitor drawer.
            if (revoked is not null)
                _db.Set<RfidCard>().Remove(revoked);

            var now = DateTime.UtcNow;
            var card = new VisitorCard
            {
                RfidTagId = tag,
                Label = label,
                State = VisitorCardState.Active,
                CreatedAt = now,
                UpdatedAt = now
            };

            _db.Set<VisitorCard>().Add(card);
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new VisitorCardResponse
            {
                RfidTagId = card.RfidTagId,
                Label = card.Label,
                Whereabouts = "InDrawer",
                CreatedAt = card.CreatedAt
            });
        }

        public async Task<ActionResult<object>> RemoveAsync(string rfidTagId, CancellationToken ct)
        {
            var tag = RfidTag.Normalize(rfidTagId);
            var card = await _db.Set<VisitorCard>().FindAsync([tag], ct);
            if (card is null)
                return new NotFoundObjectResult(new { message = "Visitor card not found." });

            // A card that is out with a visitor cannot be taken off the list:
            // the exit tap finds the car through it.
            if (await _db.Set<VisitorPass>().AnyAsync(p => p.RfidTagId == tag && p.ReturnedAt == null, ct))
                return new BadRequestObjectResult(new
                {
                    message = $"Visitor card {card.Label} is out with a visitor. Take it back first."
                });

            // Past passes keep their visitor details. They name the card by its
            // UID, so after this the history shows the UID instead of the label.
            _db.Set<VisitorCard>().Remove(card);
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new { message = $"Visitor card {card.Label} removed." });
        }
    }
}
