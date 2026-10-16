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
        private const int MaxFollowUpLength = 2000;

        private readonly IRepository<Incident> _incidents;
        private readonly IRepository<IncidentEvidence> _evidence;
        private readonly IFileStorageService _fileStorage;
        private readonly INotificationService _notificationService;
        private readonly AppDbContext _db;
        private readonly ILogger<IncidentService> _logger;
        private readonly IStaffAlerts? _staffAlerts;

        public IncidentService(
            IRepository<Incident> incidents,
            IRepository<IncidentEvidence> evidence,
            IFileStorageService fileStorage,
            INotificationService notificationService,
            AppDbContext db,
            ILogger<IncidentService> logger,
            IStaffAlerts? staffAlerts = null)
        {
            _staffAlerts = staffAlerts;
            _logger = logger;
            _incidents = incidents;
            _evidence = evidence;
            _fileStorage = fileStorage;
            _notificationService = notificationService;
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

            // Files first, report second. The other way round, a failed upload
            // left a report saved without the photos it was filed with. At the
            // guard post an upload needs the internet, so this is a real case
            // there, not a rare one.
            var stored = new List<IncidentEvidence>();
            try
            {
                foreach (var file in files)
                {
                    var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                    var objectPath = $"incident-evidence/{incident.Id}/{Guid.NewGuid()}{ext}";
                    await _fileStorage.SaveFileAsync(objectPath, file, ct);

                    stored.Add(new IncidentEvidence
                    {
                        Id = Guid.NewGuid(),
                        IncidentId = incident.Id,
                        StoragePath = objectPath,
                        FileName = file.FileName,
                        UploadedAt = DateTime.UtcNow
                    });
                }
            }
            catch (Exception ex) when (!ct.IsCancellationRequested)
            {
                _logger.LogWarning(ex, "Incident attachments could not be stored; the report was not saved.");
                return new ObjectResult(new
                {
                    message = "The photos could not be uploaded, so the report was not saved. " +
                              "Try again, or send the report without photos."
                })
                { StatusCode = StatusCodes.Status503ServiceUnavailable };
            }

            await _incidents.AddAsync(incident, ct);
            foreach (var evidence in stored)
                await _evidence.AddAsync(evidence, ct);

            await _incidents.SaveAsync(ct);

            if (_staffAlerts is not null)
                await _staffAlerts.RaiseAsync(StaffAlertKind.Incident, reporterUserId, ct);

            return new OkObjectResult(new { message = "Incident reported.", incidentId = incident.Id });
        }

        // GET /api/incidents
        public Task<ActionResult<IncidentListResponse>> GetMyIncidentsAsync(Guid userId, int page, int pageSize, CancellationToken ct)
            => ListAsync(_db.Set<Incident>().AsNoTracking().Where(i => i.ReportedByUserId == userId), page, pageSize, includeFollowUps: false, ct);

        // GET /api/incidents/{id}
        public Task<ActionResult<IncidentDetailResponse>> GetMyIncidentDetailAsync(Guid userId, Guid incidentId, CancellationToken ct)
            => GetDetailAsync(i => i.Id == incidentId && i.ReportedByUserId == userId, includeFollowUps: false, ct);

        // PUT /api/incidents/{id}
        public async Task<ActionResult<object>> UpdateMyIncidentAsync(
            Guid userId, Guid incidentId, UpdateIncidentDto dto, CancellationToken ct)
        {
            if (!Enum.TryParse<IncidentCategory>(dto.Category, true, out var category))
                return new BadRequestObjectResult(new { message = "Invalid incident category." });

            if (string.IsNullOrWhiteSpace(dto.Description))
                return new BadRequestObjectResult(new { message = "Description is required." });

            var incident = await _incidents.FindAsync(
                i => i.Id == incidentId && i.ReportedByUserId == userId, ct);

            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            // Editable only before anyone has looked at it, otherwise an admin's
            // notes could end up attached to a report that has since changed.
            if (incident.Status != IncidentStatus.Submitted)
                return new BadRequestObjectResult(new
                {
                    message = "This report can no longer be edited because it is already being reviewed."
                });

            incident.Category = category;
            incident.Description = dto.Description.Trim();
            incident.Location = dto.Location;
            incident.UpdatedAt = DateTime.UtcNow;

            _incidents.Update(incident);
            await _incidents.SaveAsync(ct);

            return new OkObjectResult(new { message = "Report updated." });
        }

        // POST /api/incidents/{id}/withdraw
        public async Task<ActionResult<object>> WithdrawMyIncidentAsync(
            Guid userId, Guid incidentId, CancellationToken ct)
        {
            var incident = await _incidents.FindAsync(
                i => i.Id == incidentId && i.ReportedByUserId == userId, ct);

            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            if (incident.Status != IncidentStatus.Submitted)
                return new BadRequestObjectResult(new
                {
                    message = "This report can no longer be withdrawn because it is already being reviewed."
                });

            incident.Status = IncidentStatus.Withdrawn;
            incident.UpdatedAt = DateTime.UtcNow;

            _incidents.Update(incident);
            await _incidents.SaveAsync(ct);

            return new OkObjectResult(new { message = "Report withdrawn." });
        }

        // GET /api/admin/incidents
        public Task<ActionResult<IncidentListResponse>> ListAllAsync(string? status, string? search, int page, int pageSize, CancellationToken ct)
        {
            var query = _db.Set<Incident>().AsNoTracking();

            if (!string.IsNullOrWhiteSpace(status))
            {
                // A typo'd status used to fall through and list everything,
                // which looks like a filter that does nothing.
                if (!Enum.TryParse<IncidentStatus>(status, true, out var parsedStatus))
                    return Task.FromResult<ActionResult<IncidentListResponse>>(
                        new BadRequestObjectResult(new { message = "Invalid incident status." }));

                query = query.Where(i => i.Status == parsedStatus);
            }

            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(i => i.ReportedByUser.FullName.ToLower().Contains(term));
            }

            return ListAsync(query, page, pageSize, includeFollowUps: true, ct);
        }

        // GET /api/admin/incidents/{id}
        public Task<ActionResult<IncidentDetailResponse>> GetDetailForAdminAsync(Guid incidentId, CancellationToken ct)
            => GetDetailAsync(i => i.Id == incidentId, includeFollowUps: true, ct);

        // POST /api/admin/incidents/{id}/start-review
        public async Task<ActionResult<object>> StartReviewAsync(Guid incidentId, Guid adminUserId, CancellationToken ct)
        {
            var incident = await _incidents.FindAsync(i => i.Id == incidentId, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            // Only a fresh report moves. Opening one that is already under
            // review, decided or withdrawn changes nothing.
            if (incident.Status != IncidentStatus.Submitted)
                return new OkObjectResult(new { message = "Already past submission.", status = incident.Status.ToString() });

            incident.Status = IncidentStatus.UnderReview;
            incident.ReviewedByUserId = adminUserId;
            incident.UpdatedAt = DateTime.UtcNow;

            _incidents.Update(incident);
            await _incidents.SaveAsync(ct);

            await NotifyReporterAsync(incident, IncidentStatus.UnderReview, null, ct);

            return new OkObjectResult(new { message = "Review started.", status = incident.Status.ToString() });
        }

        // PUT /api/admin/incidents/{id}/review
        public async Task<ActionResult<object>> ReviewAsync(Guid incidentId, Guid adminUserId, ReviewIncidentDto dto, CancellationToken ct)
        {
            if (!Enum.TryParse<IncidentStatus>(dto.Status, true, out var status)
                || (status != IncidentStatus.Resolved && status != IncidentStatus.Dismissed))
                return new BadRequestObjectResult(new { message = "A report can only be resolved or dismissed." });

            if (string.IsNullOrWhiteSpace(dto.AdminNotes))
                return new BadRequestObjectResult(new { message = "Write a note explaining the decision." });

            var incident = await _incidents.FindAsync(i => i.Id == incidentId, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            // A decision is final. Withdrawn is the reporter's own call, so it
            // is not the admin's to overwrite either.
            if (incident.Status != IncidentStatus.Submitted && incident.Status != IncidentStatus.UnderReview)
                return new BadRequestObjectResult(new
                {
                    message = $"This report is already {incident.Status.ToString().ToLowerInvariant()} and can no longer be changed."
                });

            var now = DateTime.UtcNow;
            incident.Status = status;
            incident.AdminNotes = dto.AdminNotes.Trim();
            incident.ReviewedByUserId = adminUserId;
            incident.ReviewedAt = now;
            // UpdatedAt is also the key the site-server sync uses to decide
            // which copy of a report is newer, so it moves with every change.
            incident.UpdatedAt = now;

            _incidents.Update(incident);
            await _incidents.SaveAsync(ct);

            await NotifyReporterAsync(incident, status, incident.AdminNotes, ct);

            return new OkObjectResult(new { message = "Incident reviewed." });
        }

        // Somebody took the trouble to report something; they hear back each
        // time it moves, instead of opening the list to find out.
        private Task NotifyReporterAsync(Incident incident, IncidentStatus status, string? adminNotes, CancellationToken ct)
        {
            var notes = string.IsNullOrWhiteSpace(adminNotes)
                ? string.Empty
                : $" Note: {adminNotes}";

            var (title, message) = status switch
            {
                IncidentStatus.UnderReview => (
                    "Your report is being reviewed",
                    $"Someone is looking into the {incident.Category} you reported."),
                IncidentStatus.Resolved => (
                    "Your report was resolved",
                    $"The {incident.Category} you reported has been dealt with. Thank you for flagging it.{notes}"),
                IncidentStatus.Dismissed => (
                    "Your report was closed",
                    $"The {incident.Category} you reported was reviewed and closed without further action.{notes}"),
                _ => (
                    "Your report was updated",
                    $"The status of your report is now {status}.{notes}")
            };

            return _notificationService.NotifyUserAsync(
                incident.ReportedByUserId,
                NotificationType.Incident,
                title,
                message,
                new Dictionary<string, string> { ["incidentId"] = incident.Id.ToString() },
                ct);
        }

        private async Task<ActionResult<IncidentListResponse>> ListAsync(
            IQueryable<Incident> query, int page, int pageSize, bool includeFollowUps, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var totalCount = await query.CountAsync(ct);

            var rows = await query
                .OrderByDescending(i => i.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(i => new
                {
                    i.Id,
                    i.Category,
                    i.Status,
                    i.CreatedAt,
                    i.Description,
                    i.Location,
                    i.ReviewedAt,
                    FollowUps = includeFollowUps
                        ? _db.Set<IncidentFollowUp>().Count(f => f.IncidentId == i.Id)
                        : 0,
                    NewFollowUps = includeFollowUps
                        ? _db.Set<IncidentFollowUp>().Count(f => f.IncidentId == i.Id && f.SeenByAdminAt == null)
                        : 0,
                    ReporterName = i.ReportedByUser.FullName,
                    ReporterRole = i.ReportedByUser.Role
                })
                .ToListAsync(ct);

            var incidents = rows.Select(r => new IncidentSummaryResponse
            {
                IncidentId = r.Id,
                Category = r.Category.ToString(),
                Status = r.Status.ToString(),
                CreatedAt = r.CreatedAt,
                DescriptionPreview = IncidentSummaryResponse.Preview(r.Description),
                Location = r.Location,
                ReviewedAt = r.ReviewedAt,
                FollowUpCount = r.FollowUps,
                HasNewFollowUp = r.NewFollowUps > 0,
                ReportedByName = r.ReporterName,
                ReportedByRole = r.ReporterRole.ToString()
            }).ToList();

            return new OkObjectResult(new IncidentListResponse
            {
                Incidents = incidents,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        private async Task<ActionResult<IncidentDetailResponse>> GetDetailAsync(
            System.Linq.Expressions.Expression<Func<Incident, bool>> predicate, bool includeFollowUps, CancellationToken ct)
        {
            var incident = await _db.Set<Incident>().AsNoTracking().FirstOrDefaultAsync(predicate, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            var evidence = await _db.Set<IncidentEvidence>().AsNoTracking()
                .Where(e => e.IncidentId == incident.Id)
                .ToListAsync(ct);

            // One attachment out of reach — the guard post with no internet —
            // should cost that attachment, not the whole report.
            var evidenceUrls = new List<string>();
            var evidenceItems = new List<IncidentEvidenceItem>();
            var unavailable = 0;
            foreach (var e in evidence)
            {
                try
                {
                    var url = await _fileStorage.GetFileUrlAsync(e.StoragePath, ct);
                    evidenceUrls.Add(url);
                    evidenceItems.Add(new IncidentEvidenceItem { Url = url, FileName = e.FileName });
                }
                catch (Exception ex) when (!ct.IsCancellationRequested)
                {
                    unavailable++;
                    _logger.LogWarning(ex, "Could not open incident attachment {Path}.", e.StoragePath);
                }
            }

            var reporter = await _db.Set<User>().AsNoTracking()
                .Where(u => u.Id == incident.ReportedByUserId)
                .Select(u => new { u.FullName, u.Role })
                .FirstOrDefaultAsync(ct);

            var followUps = includeFollowUps
                ? await LoadFollowUpsAsync(incident.Id, ct)
                : [];

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
                EvidenceUrls = evidenceUrls,
                Evidence = evidenceItems,
                EvidenceUnavailable = unavailable,
                ReportedByName = reporter?.FullName,
                ReportedByRole = reporter?.Role.ToString(),
                ReviewedAt = incident.ReviewedAt,
                FollowUps = followUps
            });
        }

        private async Task<List<IncidentFollowUpItem>> LoadFollowUpsAsync(Guid incidentId, CancellationToken ct)
        {
            var rows = await _db.Set<IncidentFollowUp>().AsNoTracking()
                .Where(f => f.IncidentId == incidentId)
                .OrderBy(f => f.CreatedAt)
                .ToListAsync(ct);

            var authorIds = rows.Select(r => r.AuthorUserId).Distinct().ToList();
            var names = await _db.Set<User>().AsNoTracking()
                .Where(u => authorIds.Contains(u.Id))
                .ToDictionaryAsync(u => u.Id, u => u.FullName, ct);

            var items = new List<IncidentFollowUpItem>();
            foreach (var row in rows)
            {
                // A file out of reach costs the attachment, not the note.
                string? url = null;
                if (!string.IsNullOrEmpty(row.AttachmentPath))
                {
                    try
                    {
                        url = await _fileStorage.GetFileUrlAsync(row.AttachmentPath, ct);
                    }
                    catch (Exception ex) when (!ct.IsCancellationRequested)
                    {
                        _logger.LogWarning(ex, "Could not open follow-up attachment {Path}.", row.AttachmentPath);
                    }
                }

                items.Add(new IncidentFollowUpItem
                {
                    FollowUpId = row.Id,
                    AuthorName = names.TryGetValue(row.AuthorUserId, out var name) ? name : "Security",
                    Note = row.Note,
                    CreatedAt = row.CreatedAt,
                    AttachmentUrl = url,
                    AttachmentName = row.AttachmentName,
                    IsNew = row.SeenByAdminAt is null
                });
            }

            return items;
        }

        // POST /api/admin/incidents/{id}/follow-ups
        public async Task<ActionResult<object>> AddFollowUpAsync(
            Guid incidentId, Guid securityUserId, AddIncidentFollowUpDto dto, CancellationToken ct)
        {
            var note = dto.Note?.Trim() ?? string.Empty;
            if (note.Length == 0)
                return new BadRequestObjectResult(new { message = "Write what you found out." });
            if (note.Length > MaxFollowUpLength)
                return new BadRequestObjectResult(new { message = $"Keep it under {MaxFollowUpLength} characters." });

            var file = dto.Attachment;
            if (file is not null)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!AllowedExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"Unsupported file type: {ext}" });
                if (file.Length > MaxFileSizeBytes)
                    return new BadRequestObjectResult(new { message = "The attachment must be 5MB or smaller." });
            }

            var incident = await _incidents.FindAsync(i => i.Id == incidentId, ct);
            if (incident is null)
                return new NotFoundObjectResult(new { message = "Incident not found." });

            // Once decided or withdrawn the report is final, and so is what
            // was written about it.
            if (incident.Status != IncidentStatus.Submitted && incident.Status != IncidentStatus.UnderReview)
                return new BadRequestObjectResult(new
                {
                    message = $"This report is already {incident.Status.ToString().ToLowerInvariant()}, so follow-ups can no longer be added."
                });

            var followUp = new IncidentFollowUp
            {
                Id = Guid.NewGuid(),
                IncidentId = incident.Id,
                AuthorUserId = securityUserId,
                Note = note,
                CreatedAt = DateTime.UtcNow
            };

            // File first, note second: a note that promises a photo it does not
            // have is worse than none. At the guard post this needs the internet.
            if (file is not null)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                var objectPath = $"incident-evidence/{incident.Id}/{Guid.NewGuid()}{ext}";
                try
                {
                    await _fileStorage.SaveFileAsync(objectPath, file, ct);
                }
                catch (Exception ex) when (!ct.IsCancellationRequested)
                {
                    _logger.LogWarning(ex, "Follow-up attachment could not be stored; the note was not saved.");
                    return new ObjectResult(new
                    {
                        message = "The attachment could not be uploaded, so the note was not saved. " +
                                  "Try again, or add the note without it."
                    })
                    { StatusCode = StatusCodes.Status503ServiceUnavailable };
                }

                followUp.AttachmentPath = objectPath;
                followUp.AttachmentName = file.FileName;
            }

            _db.Set<IncidentFollowUp>().Add(followUp);
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new { message = "Follow-up added.", followUpId = followUp.Id });
        }

        // POST /api/admin/incidents/{id}/follow-ups/seen
        public async Task<ActionResult<object>> MarkFollowUpsSeenAsync(Guid incidentId, CancellationToken ct)
        {
            var unseen = await _db.Set<IncidentFollowUp>()
                .Where(f => f.IncidentId == incidentId && f.SeenByAdminAt == null)
                .ToListAsync(ct);

            if (unseen.Count == 0)
                return new OkObjectResult(new { message = "Nothing new." });

            var now = DateTime.UtcNow;
            foreach (var f in unseen)
                f.SeenByAdminAt = now;

            await _db.SaveChangesAsync(ct);
            return new OkObjectResult(new { message = "Marked as read." });
        }
    }
}
