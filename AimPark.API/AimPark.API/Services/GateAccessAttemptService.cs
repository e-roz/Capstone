using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class GateAccessAttemptService : IGateAccessAttemptService
    {
        private readonly AppDbContext _db;

        public GateAccessAttemptService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ActionResult<GateAccessAttemptListResponse>> ListAsync(
            bool includeReviewed, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<GateAccessAttempt>().AsNoTracking();

            if (!includeReviewed)
                query = query.Where(a => a.ReviewedAt == null);

            var totalCount = await query.CountAsync(ct);

            var items = await query
                .OrderByDescending(a => a.AttemptedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(a => new GateAccessAttemptResponse
                {
                    Id = a.Id,
                    Gate = a.Gate,
                    RfidTagId = a.RfidTagId,
                    Holder = a.UserId != null ? "User" : a.VisitorPassId != null ? "Visitor" : "Unknown",
                    HolderName = a.User != null
                        ? a.User.FullName
                        : a.VisitorPass != null
                            ? a.VisitorPass.VisitorName
                            : null,
                    Outcome = a.Outcome == GateAccessOutcome.PlateMismatch
                        ? AllocationResult.PlateMismatch
                        : AllocationResult.AlprUnavailable,
                    AlprPlateNumber = a.AlprPlateNumber,
                    AlprConfidence = a.AlprConfidence,
                    AttemptedAt = a.AttemptedAt,
                    IsReviewed = a.ReviewedAt != null,
                    ReviewedByName = a.ReviewedByUser != null ? a.ReviewedByUser.FullName : null,
                    ReviewedAt = a.ReviewedAt,
                    WasOverridden = a.ResultingLogId != null
                })
                .ToListAsync(ct);

            return new OkObjectResult(new GateAccessAttemptListResponse
            {
                Items = items,
                Page = page,
                PageSize = pageSize,
                TotalCount = totalCount
            });
        }

        public async Task<ActionResult<object>> DismissAsync(
            Guid attemptId, Guid reviewedByUserId, CancellationToken ct)
        {
            var attempt = await _db.Set<GateAccessAttempt>()
                .FirstOrDefaultAsync(a => a.Id == attemptId, ct);

            if (attempt is null)
                return new NotFoundObjectResult(new { message = "Attempt not found." });

            if (attempt.ReviewedAt is not null)
                return new BadRequestObjectResult(new { message = "This attempt was already reviewed." });

            attempt.ReviewedByUserId = reviewedByUserId;
            attempt.ReviewedAt = DateTime.UtcNow;

            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new { message = "Dismissed." });
        }
    }
}
