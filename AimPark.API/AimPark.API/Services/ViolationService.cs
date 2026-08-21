using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class ViolationService : IViolationService
    {
        private static readonly string[] AllowedEvidenceExtensions = [".jpg", ".jpeg", ".png", ".pdf"];
        private const int MaxEvidenceFiles = 5;
        private const long MaxEvidenceFileBytes = 5 * 1024 * 1024;

        private readonly IRepository<PolicyRule> _rules;
        private readonly IRepository<Violation> _violations;
        private readonly IRepository<ViolationAppeal> _appeals;
        private readonly IRepository<User> _users;
        private readonly IPaymentService _paymentService;
        private readonly INotificationService _notificationService;
        private readonly IFileStorageService _fileStorage;
        private readonly AppDbContext _db;

        public ViolationService(
            IRepository<PolicyRule> rules,
            IRepository<Violation> violations,
            IRepository<ViolationAppeal> appeals,
            IRepository<User> users,
            IPaymentService paymentService,
            INotificationService notificationService,
            IFileStorageService fileStorage,
            AppDbContext db)
        {
            _fileStorage = fileStorage;
            _rules = rules;
            _violations = violations;
            _appeals = appeals;
            _users = users;
            _paymentService = paymentService;
            _notificationService = notificationService;
            _db = db;
        }

        // ---------- Policy rules ----------

        // GET /api/admin/policy-rules
        public async Task<ActionResult<List<PolicyRuleResponse>>> ListPolicyRulesAsync(CancellationToken ct)
        {
            var rules = await _db.Set<PolicyRule>().AsNoTracking()
                .OrderBy(r => r.Title)
                .ToListAsync(ct);

            return new OkObjectResult(rules.Select(ToRuleResponse).ToList());
        }

        // POST /api/admin/policy-rules
        public async Task<ActionResult<object>> CreatePolicyRuleAsync(UpsertPolicyRuleDto dto, CancellationToken ct)
        {
            var validation = ValidateRuleDto(dto, out var suspensionType, out var category);
            if (validation is not null)
                return validation;

            var now = DateTime.UtcNow;
            var rule = new PolicyRule
            {
                Id = Guid.NewGuid(),
                Title = dto.Title.Trim(),
                Description = dto.Description.Trim(),
                Category = category,
                DefaultPenaltyAmount = dto.DefaultPenaltyAmount,
                DefaultSuspensionType = suspensionType,
                DefaultSuspensionDays = dto.DefaultSuspensionDays,
                IsActive = dto.IsActive,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _rules.AddAsync(rule, ct);
            await _rules.SaveAsync(ct);

            return new OkObjectResult(new { message = "Policy rule created.", ruleId = rule.Id });
        }

        // PUT /api/admin/policy-rules/{id}
        public async Task<ActionResult<object>> UpdatePolicyRuleAsync(Guid ruleId, UpsertPolicyRuleDto dto, CancellationToken ct)
        {
            var validation = ValidateRuleDto(dto, out var suspensionType, out var category);
            if (validation is not null)
                return validation;

            var rule = await _rules.FindAsync(r => r.Id == ruleId, ct);
            if (rule is null)
                return new NotFoundObjectResult(new { message = "Policy rule not found." });

            rule.Title = dto.Title.Trim();
            rule.Description = dto.Description.Trim();
            rule.Category = category;
            rule.DefaultPenaltyAmount = dto.DefaultPenaltyAmount;
            rule.DefaultSuspensionType = suspensionType;
            rule.DefaultSuspensionDays = dto.DefaultSuspensionDays;
            rule.IsActive = dto.IsActive;
            rule.UpdatedAt = DateTime.UtcNow;

            _rules.Update(rule);
            await _rules.SaveAsync(ct);

            return new OkObjectResult(new { message = "Policy rule updated." });
        }

        // ---------- Violations ----------

        // POST /api/admin/violations
        public async Task<ActionResult<object>> IssueAsync(IssueViolationDto dto, Guid adminUserId, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Description))
                return new BadRequestObjectResult(new { message = "Description is required." });

            var user = await _users.FindAsync(u => u.Id == dto.UserId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var rule = await _rules.FindAsync(r => r.Id == dto.PolicyRuleId, ct);
            if (rule is null)
                return new NotFoundObjectResult(new { message = "Policy rule not found." });

            var suspensionType = rule.DefaultSuspensionType;
            if (!string.IsNullOrWhiteSpace(dto.SuspensionTypeOverride))
            {
                if (!Enum.TryParse<SuspensionType>(dto.SuspensionTypeOverride, true, out suspensionType))
                    return new BadRequestObjectResult(new { message = "Invalid suspension type override." });
            }

            var suspensionDays = dto.SuspensionDaysOverride ?? rule.DefaultSuspensionDays;
            if (suspensionType == SuspensionType.Temporary && (suspensionDays is null || suspensionDays <= 0))
                return new BadRequestObjectResult(new { message = "Temporary suspension requires a positive number of days." });

            var penaltyAmount = dto.PenaltyAmountOverride ?? rule.DefaultPenaltyAmount;
            if (penaltyAmount < 0)
                return new BadRequestObjectResult(new { message = "Penalty amount must be zero or greater." });

            if (dto.ParkingLogId is not null)
            {
                var logExists = await _db.Set<ParkingLog>().AnyAsync(l => l.Id == dto.ParkingLogId, ct);
                if (!logExists)
                    return new NotFoundObjectResult(new { message = "Parking log not found." });
            }

            var now = DateTime.UtcNow;
            var violation = new Violation
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                PolicyRuleId = rule.Id,
                ParkingLogId = dto.ParkingLogId,
                Description = dto.Description.Trim(),
                PenaltyAmount = penaltyAmount,
                SuspensionType = suspensionType,
                SuspensionDays = suspensionType == SuspensionType.Temporary ? suspensionDays : null,
                Status = ViolationStatus.Issued,
                IssuedByUserId = adminUserId,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _violations.AddAsync(violation, ct);
            await _violations.SaveAsync(ct);

            if (suspensionType != SuspensionType.None)
                ApplySuspension(user, suspensionType, suspensionDays);

            _users.Update(user);
            await _users.SaveAsync(ct);

            await _paymentService.CreateForViolationAsync(violation, ct);

            // Without this the user never learns they were penalised, which also
            // makes the appeal window meaningless — they cannot contest something
            // they have not been told about.
            var suspensionNote = suspensionType switch
            {
                SuspensionType.Permanent => " Your RFID access has been suspended.",
                SuspensionType.Temporary => $" Your RFID access is suspended for {suspensionDays} day(s).",
                _ => string.Empty
            };

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Violation,
                $"Violation: {rule.Title}",
                $"A penalty of ₱{penaltyAmount:0.00} has been issued.{suspensionNote} Open the app to view details or appeal.",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Violation issued.", violationId = violation.Id });
        }

        // GET /api/violations
        public Task<ActionResult<ViolationListResponse>> GetMyViolationsAsync(Guid userId, int page, int pageSize, CancellationToken ct)
            => ListViolationsAsync(_db.Set<Violation>().AsNoTracking().Where(v => v.UserId == userId), page, pageSize, ct);

        // GET /api/violations/{id}
        public Task<ActionResult<ViolationDetailResponse>> GetMyViolationDetailAsync(Guid userId, Guid violationId, CancellationToken ct)
            => GetViolationDetailAsync(v => v.Id == violationId && v.UserId == userId, ct);

        // GET /api/admin/violations
        public Task<ActionResult<ViolationListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct)
        {
            var query = _db.Set<Violation>().AsNoTracking();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<ViolationStatus>(status, true, out var parsedStatus))
                query = query.Where(v => v.Status == parsedStatus);

            return ListViolationsAsync(query, page, pageSize, ct);
        }

        // GET /api/admin/violations/{id}
        public Task<ActionResult<ViolationDetailResponse>> GetDetailForAdminAsync(Guid violationId, CancellationToken ct)
            => GetViolationDetailAsync(v => v.Id == violationId, ct);

        // PUT /api/admin/violations/{id}/dismiss
        public async Task<ActionResult<object>> DismissAsync(Guid violationId, Guid adminUserId, CancellationToken ct)
        {
            var violation = await _violations.FindAsync(v => v.Id == violationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            if (violation.Status is ViolationStatus.Overturned or ViolationStatus.Dismissed)
                return new BadRequestObjectResult(new { message = "This violation is already resolved." });

            violation.Status = ViolationStatus.Dismissed;
            violation.UpdatedAt = DateTime.UtcNow;
            _violations.Update(violation);
            await _violations.SaveAsync(ct);

            if (violation.SuspensionType != SuspensionType.None)
            {
                var user = await _users.FindAsync(u => u.Id == violation.UserId, ct);
                if (user is not null)
                {
                    ReverseSuspension(user);
                    _users.Update(user);
                    await _users.SaveAsync(ct);
                }
            }

            await _paymentService.WaiveForViolationAsync(violationId, ct);

            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                "Violation dismissed",
                "A violation on your record has been dismissed and its penalty waived.",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Violation dismissed." });
        }

        // PUT /api/admin/violations/{id}
        public async Task<ActionResult<object>> UpdateAsync(
            Guid violationId, Guid adminUserId, UpdateViolationDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Description))
                return new BadRequestObjectResult(new { message = "Description is required." });

            if (dto.PenaltyAmount < 0)
                return new BadRequestObjectResult(new { message = "Penalty amount must be zero or greater." });

            if (!Enum.TryParse<SuspensionType>(dto.SuspensionType, true, out var suspensionType))
                return new BadRequestObjectResult(new { message = "Invalid suspension type." });

            if (suspensionType == SuspensionType.Temporary && (dto.SuspensionDays is null || dto.SuspensionDays <= 0))
                return new BadRequestObjectResult(new { message = "Temporary suspension requires a positive number of days." });

            var violation = await _violations.FindAsync(v => v.Id == violationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            // Editable only while untouched. Once it has been appealed or decided,
            // this row is the thing both sides argued about.
            if (violation.Status != ViolationStatus.Issued)
                return new BadRequestObjectResult(new
                {
                    message = "Only a violation still in Issued status can be edited."
                });

            var previousSuspension = violation.SuspensionType;

            violation.Description = dto.Description.Trim();
            violation.PenaltyAmount = dto.PenaltyAmount;
            violation.SuspensionType = suspensionType;
            violation.SuspensionDays = suspensionType == SuspensionType.Temporary ? dto.SuspensionDays : null;
            violation.UpdatedAt = DateTime.UtcNow;

            _violations.Update(violation);
            await _violations.SaveAsync(ct);

            // Correcting the penalty has to correct the access consequence too,
            // or a user stays locked out over a suspension that was withdrawn.
            if (previousSuspension != suspensionType)
            {
                var user = await _users.FindAsync(u => u.Id == violation.UserId, ct);
                if (user is not null)
                {
                    if (suspensionType == SuspensionType.None)
                        ReverseSuspension(user);
                    else
                        ApplySuspension(user, suspensionType, violation.SuspensionDays);

                    _users.Update(user);
                    await _users.SaveAsync(ct);
                }
            }

            // The penalty may have moved, so the outstanding fee has to follow.
            await _paymentService.UpdateViolationAmountAsync(violation.Id, dto.PenaltyAmount, ct);

            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                "Violation updated",
                $"A violation on your record was corrected. Penalty is now ₱{dto.PenaltyAmount:0.00}.",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Violation updated." });
        }

        // ---------- Appeals ----------

        // POST /api/violations/{id}/appeal
        public async Task<ActionResult<object>> SubmitAppealAsync(Guid userId, Guid violationId, SubmitAppealDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.ReasonText))
                return new BadRequestObjectResult(new { message = "A reason is required." });

            var violation = await _violations.FindAsync(v => v.Id == violationId && v.UserId == userId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            if (violation.Status != ViolationStatus.Issued)
                return new BadRequestObjectResult(new { message = "This violation cannot be appealed." });

            var alreadyAppealed = await _appeals.ExistsAsync(a => a.ViolationId == violationId, ct);
            if (alreadyAppealed)
                return new BadRequestObjectResult(new { message = "An appeal has already been submitted for this violation." });

            var files = dto.Evidence ?? [];
            if (files.Count > MaxEvidenceFiles)
                return new BadRequestObjectResult(new { message = $"A maximum of {MaxEvidenceFiles} evidence files is allowed." });

            foreach (var file in files)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!AllowedEvidenceExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"Unsupported file type: {ext}" });

                if (file.Length > MaxEvidenceFileBytes)
                    return new BadRequestObjectResult(new { message = "Each evidence file must be 5MB or smaller." });
            }

            var appeal = new ViolationAppeal
            {
                Id = Guid.NewGuid(),
                ViolationId = violationId,
                ReasonText = dto.ReasonText.Trim(),
                Status = AppealStatus.Pending,
                CreatedAt = DateTime.UtcNow
            };

            await _appeals.AddAsync(appeal, ct);

            violation.Status = ViolationStatus.Appealed;
            violation.UpdatedAt = DateTime.UtcNow;
            _violations.Update(violation);

            await _appeals.SaveAsync(ct);

            // Uploaded after the appeal is persisted, so a storage outage costs
            // the attachments rather than the appeal itself.
            foreach (var file in files)
            {
                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                var objectPath = $"appeal-evidence/{appeal.Id}/{Guid.NewGuid()}{ext}";
                await _fileStorage.SaveFileAsync(objectPath, file, ct);

                _db.Set<AppealEvidence>().Add(new AppealEvidence
                {
                    Id = Guid.NewGuid(),
                    AppealId = appeal.Id,
                    StoragePath = objectPath,
                    FileName = file.FileName,
                    UploadedAt = DateTime.UtcNow
                });
            }

            if (files.Count > 0)
                await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new { message = "Appeal submitted." });
        }

        // GET /api/admin/violations/appeals
        public async Task<ActionResult<ViolationAppealListResponse>> ListAppealsAsync(string? status, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var query = _db.Set<ViolationAppeal>().AsNoTracking();
            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<AppealStatus>(status, true, out var parsedStatus))
                query = query.Where(a => a.Status == parsedStatus);

            var totalCount = await query.CountAsync(ct);

            var appeals = await query
                .OrderByDescending(a => a.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(a => new ViolationAppealResponse
                {
                    AppealId = a.Id,
                    ViolationId = a.ViolationId,
                    ReasonText = a.ReasonText,
                    Status = a.Status.ToString(),
                    AdminNotes = a.AdminNotes,
                    CreatedAt = a.CreatedAt,
                    DecidedAt = a.DecidedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new ViolationAppealListResponse
            {
                Appeals = appeals,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        // PUT /api/admin/violations/appeals/{id}/decide
        public async Task<ActionResult<object>> DecideAppealAsync(Guid appealId, Guid adminUserId, DecideAppealDto dto, CancellationToken ct)
        {
            var appeal = await _appeals.FindAsync(a => a.Id == appealId, ct);
            if (appeal is null)
                return new NotFoundObjectResult(new { message = "Appeal not found." });

            if (appeal.Status != AppealStatus.Pending)
                return new BadRequestObjectResult(new { message = "This appeal has already been decided." });

            var violation = await _violations.FindAsync(v => v.Id == appeal.ViolationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            appeal.Status = dto.Approve ? AppealStatus.Approved : AppealStatus.Denied;
            appeal.AdminNotes = dto.AdminNotes;
            appeal.DecidedByUserId = adminUserId;
            appeal.DecidedAt = DateTime.UtcNow;
            _appeals.Update(appeal);

            violation.Status = dto.Approve ? ViolationStatus.Overturned : ViolationStatus.Upheld;
            violation.UpdatedAt = DateTime.UtcNow;
            _violations.Update(violation);

            await _appeals.SaveAsync(ct);

            if (dto.Approve)
            {
                if (violation.SuspensionType != SuspensionType.None)
                {
                    var user = await _users.FindAsync(u => u.Id == violation.UserId, ct);
                    if (user is not null)
                    {
                        ReverseSuspension(user);
                        _users.Update(user);
                        await _users.SaveAsync(ct);
                    }
                }

                await _paymentService.WaiveForViolationAsync(violation.Id, ct);
            }

            // An appeal the user never hears back on is worse than no appeal.
            var notes = string.IsNullOrWhiteSpace(dto.AdminNotes) ? "" : $" Note: {dto.AdminNotes}";

            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                dto.Approve ? "Appeal approved" : "Appeal denied",
                dto.Approve
                    ? $"Your appeal was approved. The violation has been overturned and the penalty waived.{notes}"
                    : $"Your appeal was reviewed and the violation stands.{notes}",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Appeal decided." });
        }

        // ---------- Helpers ----------

        private static void ApplySuspension(User user, SuspensionType suspensionType, int? suspensionDays)
        {
            user.RfidStatus = RfidStatus.Suspended;
            user.RfidSuspendedUntil = suspensionType == SuspensionType.Temporary
                ? DateTime.UtcNow.AddDays(suspensionDays!.Value)
                : null;
            user.UpdatedAt = DateTime.UtcNow;
        }

        private static void ReverseSuspension(User user)
        {
            user.RfidStatus = RfidStatus.Active;
            user.RfidSuspendedUntil = null;
            user.UpdatedAt = DateTime.UtcNow;
        }

        private static BadRequestObjectResult? ValidateRuleDto(
            UpsertPolicyRuleDto dto,
            out SuspensionType suspensionType,
            out PolicyCategory category)
        {
            suspensionType = SuspensionType.None;
            category = PolicyCategory.Parking;

            if (string.IsNullOrWhiteSpace(dto.Title))
                return new BadRequestObjectResult(new { message = "Title is required." });

            if (!Enum.TryParse(dto.Category, true, out category))
                return new BadRequestObjectResult(new { message = "Invalid policy category." });

            if (dto.DefaultPenaltyAmount < 0)
                return new BadRequestObjectResult(new { message = "Default penalty amount must be zero or greater." });

            if (!Enum.TryParse(dto.DefaultSuspensionType, true, out suspensionType))
                return new BadRequestObjectResult(new { message = "Invalid default suspension type." });

            if (suspensionType == SuspensionType.Temporary && (dto.DefaultSuspensionDays is null || dto.DefaultSuspensionDays <= 0))
                return new BadRequestObjectResult(new { message = "Temporary suspension requires a positive number of default days." });

            return null;
        }

        private async Task<ActionResult<ViolationListResponse>> ListViolationsAsync(
            IQueryable<Violation> query, int page, int pageSize, CancellationToken ct)
        {
            page = Math.Max(1, page);
            pageSize = Math.Clamp(pageSize, 1, 100);

            var totalCount = await query.CountAsync(ct);

            var violations = await query
                .OrderByDescending(v => v.CreatedAt)
                .Skip((page - 1) * pageSize)
                .Take(pageSize)
                .Select(v => new ViolationSummaryResponse
                {
                    ViolationId = v.Id,
                    PolicyRuleTitle = v.PolicyRule.Title,
                    Status = v.Status.ToString(),
                    PenaltyAmount = v.PenaltyAmount,
                    SuspensionType = v.SuspensionType.ToString(),
                    CreatedAt = v.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(new ViolationListResponse
            {
                Violations = violations,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        private async Task<ActionResult<ViolationDetailResponse>> GetViolationDetailAsync(
            System.Linq.Expressions.Expression<Func<Violation, bool>> predicate, CancellationToken ct)
        {
            var violation = await _db.Set<Violation>().AsNoTracking()
                .Where(predicate)
                .Select(v => new ViolationDetailResponse
                {
                    ViolationId = v.Id,
                    PolicyRuleTitle = v.PolicyRule.Title,
                    Description = v.Description,
                    PenaltyAmount = v.PenaltyAmount,
                    SuspensionType = v.SuspensionType.ToString(),
                    SuspensionDays = v.SuspensionDays,
                    Status = v.Status.ToString(),
                    CreatedAt = v.CreatedAt,
                    UpdatedAt = v.UpdatedAt
                })
                .FirstOrDefaultAsync(ct);

            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            var appeal = await _db.Set<ViolationAppeal>().AsNoTracking()
                .Where(a => a.ViolationId == violation.ViolationId)
                .FirstOrDefaultAsync(ct);

            if (appeal is not null)
            {
                violation.AppealStatus = appeal.Status.ToString();
                violation.AppealReasonText = appeal.ReasonText;
                violation.AppealAdminNotes = appeal.AdminNotes;
                violation.AppealDecidedAt = appeal.DecidedAt;

                var evidence = await _db.Set<AppealEvidence>().AsNoTracking()
                    .Where(e => e.AppealId == appeal.Id)
                    .ToListAsync(ct);

                foreach (var item in evidence)
                    violation.AppealEvidenceUrls.Add(await _fileStorage.GetFileUrlAsync(item.StoragePath, ct));
            }

            return new OkObjectResult(violation);
        }

        private static PolicyRuleResponse ToRuleResponse(PolicyRule r) => new()
        {
            RuleId = r.Id,
            Title = r.Title,
            Description = r.Description,
            Category = r.Category.ToString(),
            DefaultPenaltyAmount = r.DefaultPenaltyAmount,
            DefaultSuspensionType = r.DefaultSuspensionType.ToString(),
            DefaultSuspensionDays = r.DefaultSuspensionDays,
            IsActive = r.IsActive,
            CreatedAt = r.CreatedAt,
            UpdatedAt = r.UpdatedAt
        };
    }
}
