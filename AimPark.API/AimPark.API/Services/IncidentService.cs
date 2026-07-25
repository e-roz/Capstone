using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class IncidentService : IIncidentService
    {
        private static readonly string[] AllowedExtensions = [".jpg", ".jpeg", ".png", ".pdf"];
        private const int MaxEvidenceFiles = 5;
        private const long MaxFileSizeBytes = 5 * 1024 * 1024;

        private readonly IRepository<Incident> _incidents;
        private readonly IRepository<IncidentEvidence> _evidence;
        private readonly IFileStorageService _fileStorage;
        private readonly AppDbContext _db;

        public IncidentService(
            IRepository<Incident> incidents,
            IRepository<IncidentEvidence> evidence,
            IFileStorageService fileStorage,
            AppDbContext db)
        {
            _incidents = incidents;
            _evidence = evidence;
            _fileStorage = fileStorage;
            _db = db;
        }

        // POST /api/incidents
        public async Task<ActionResult<object>> CreateAsync(CreateIncidentDto dto, Guid reporterUserId, CancellationToken ct)
        {
            if (!Enum.TryParse<IncidentCategory>(dto.Category, true, out var category))
                return new BadRequestObjectResult(new { message = "Invalid incident category." });

            if (string.IsNullOrWhiteSpace(dto.Description))
                return new BadRequestObjectResult(new { message = "Description is required." });

            var files = dto.Evidence ?? [];
            if (files.Count > MaxEvidenceFiles)
                return new BadRequestObjectResult(new { message = $"A maximum of {MaxEvidenceFiles} evidence files is allowed." });

            foreach (var file in files)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!AllowedExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"Unsupported file type: {ext}" });

                if (file.Length > MaxFileSizeBytes)
                    return new BadRequestObjectResult(new { message = "Each evidence file must be 5MB or smaller." });
            }

            var now = DateTime.UtcNow;
            var incident = new Incident
            {
                Id = Guid.NewGuid(),
                ReportedByUserId = reporterUserId,
                Category = category,
                Description = dto.Description.Trim(),
                Location = dto.Location,
                Status = IncidentStatus.Submitted,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _incidents.AddAsync(incident, ct);
            await _incidents.SaveAsync(ct);

            foreach (var file in files)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                var objectPath = $"incident-evidence/{incident.Id}/{Guid.NewGuid()}{ext}";
                await _fileStorage.SaveFileAsync(objectPath, file, ct);

                await _evidence.AddAsync(new IncidentEvidence
                {
                    Id = Guid.NewGuid(),
                    IncidentId = incident.Id,
                    StoragePath = objectPath,
                    FileName = file.FileName,
                    UploadedAt = DateTime.UtcNow
                }, ct);
            }

            await _evidence.SaveAsync(ct);

            return new OkObjectResult(new { message = "Incident reported.", incidentId = incident.Id });
        }

        // GET /api/incidents
        public Task<ActionResult<IncidentListResponse>> GetMyIncidentsAsync(Guid userId, int page, int pageSize, CancellationToken ct)
            => ListAsync(_db.Set<Incident>().AsNoTracking().Where(i => i.ReportedByUserId == userId), page, pageSize, ct);

        // GET /api/incidents/{id}
        public Task<ActionResult<IncidentDetailResponse>> GetMyIncidentDetailAsync(Guid userId, Guid incidentId, CancellationToken ct)
            => GetDetailAsync(i => i.Id == incidentId && i.ReportedByUserId == userId, ct);

        // GET /api/admin/incidents
        public Task<ActionResult<IncidentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct)
        {
            var query = _db.Set<Incident>().AsNoTracking();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<IncidentStatus>(status, true, out var parsedStatus))
                query = query.Where(i => i.Status == parsedStatus);

            return ListAsync(query, page, pageSize, ct);
        }

        // GET /api/admin/incidents/{id}
        public Task<ActionResult<IncidentDetailResponse>> GetDetailForAdminAsync(Guid incidentId, CancellationToken ct)
            => GetDetailAsync(i => i.Id == incidentId, ct);

        // PUT /api/admin/incidents/{id}/review
        public async Task<ActionResult<object>> ReviewAsync(Guid incidentId, Guid adminUserId, ReviewIncidentDto dto, CancellationToken ct)
        {
            if (!Enum.TryParse<IncidentStatus>(dto.Status, true, out var status))
                return new BadRequestObjectResult(new { message = "Invalid incident status." });

            var incident = await _incidents.FindAsync(i => i.Id == incidentId, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            incident.Status = status;
            incident.AdminNotes = dto.AdminNotes;
            incident.ReviewedByUserId = adminUserId;
            incident.UpdatedAt = DateTime.UtcNow;

            _incidents.Update(incident);
            await _incidents.SaveAsync(ct);

            return new OkObjectResult(new { message = "Incident reviewed." });
        }

        private static async Task<ActionResult<IncidentListResponse>> ListAsync(
            IQueryable<Incident> query, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var totalCount = await query.CountAsync(ct);

            var incidents = await query
                .OrderByDescending(i => i.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(i => new IncidentSummaryResponse
                {
                    IncidentId = i.Id,
                    Category = i.Category.ToString(),
                    Status = i.Status.ToString(),
                    CreatedAt = i.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new IncidentListResponse
            {
                Incidents = incidents,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        private async Task<ActionResult<IncidentDetailResponse>> GetDetailAsync(
            System.Linq.Expressions.Expression<Func<Incident, bool>> predicate, CancellationToken ct)
        {
            var incident = await _db.Set<Incident>().AsNoTracking().FirstOrDefaultAsync(predicate, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            var evidence = await _db.Set<IncidentEvidence>().AsNoTracking()
                .Where(e => e.IncidentId == incident.Id)
                .ToListAsync(ct);

            var evidenceUrls = new List<string>();
            foreach (var e in evidence)
                evidenceUrls.Add(await _fileStorage.GetFileUrlAsync(e.StoragePath, ct));

            return new OkObjectResult(new IncidentDetailResponse
            {
                IncidentId = incident.Id,
                Category = incident.Category.ToString(),
                Description = incident.Description,
                Location = incident.Location,
                Status = incident.Status.ToString(),
                AdminNotes = incident.AdminNotes,
                CreatedAt = incident.CreatedAt,
                UpdatedAt = incident.UpdatedAt,
                EvidenceUrls = evidenceUrls
            });
        }
    }
}
