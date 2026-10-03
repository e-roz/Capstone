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
        private readonly IAdminUserService _adminUsers;
        private readonly AppDbContext _db;

        public ViolationService(
            IRepository<PolicyRule> rules,
            IRepository<Violation> violations,
            IRepository<ViolationAppeal> appeals,
            IRepository<User> users,
            IPaymentService paymentService,
            INotificationService notificationService,
            IFileStorageService fileStorage,
            IAdminUserService adminUsers,
            AppDbContext db)
        {
            _adminUsers = adminUsers;
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
                AppealWindowDays = Math.Max(0, dto.AppealWindowDays),
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
            rule.AppealWindowDays = Math.Max(0, dto.AppealWindowDays);
            rule.IsActive = dto.IsActive;
            rule.UpdatedAt = DateTime.UtcNow;

            _rules.Update(rule);
            await _rules.SaveAsync(ct);

            return new OkObjectResult(new { message = "Policy rule updated." });
        }

        // ---------- Violations ----------

        /// <summary>
        /// The shortest appeal deadline any violation gets. A rule whose
        /// suspension starts at once still leaves the user this long to contest
        /// it — stopping someone today and hearing them out are separate things.
        /// </summary>
        public const int MinimumAppealDays = 3;

        /// <summary>The number of Accountable violations that costs a user their RFID card.</summary>
        public const int StrikesBeforeRevoke = 3;

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

            if (!rule.IsActive)
                return new BadRequestObjectResult(new { message = "This policy rule is inactive." });

            if (dto.ParkingLogId is not null)
            {
                var logExists = await _db.Set<ParkingLog>().AnyAsync(l => l.Id == dto.ParkingLogId, ct);
                if (!logExists)
                    return new NotFoundObjectResult(new { message = "Parking log not found." });
            }

            // The rule is the penalty. No overrides: two people who broke the
            // same rule get the same consequence.
            var suspensionType = rule.DefaultSuspensionType;
            var suspensionDays = suspensionType == SuspensionType.Temporary ? rule.DefaultSuspensionDays : null;

            var now = DateTime.UtcNow;
            var windowDays = Math.Max(0, rule.AppealWindowDays);
            var isImmediate = windowDays == 0;

            var violation = new Violation
            {
                Id = Guid.NewGuid(),
                UserId = user.Id,
                PolicyRuleId = rule.Id,
                ParkingLogId = dto.ParkingLogId,
                Description = dto.Description.Trim(),
                PenaltyAmount = rule.DefaultPenaltyAmount,
                SuspensionType = suspensionType,
                SuspensionDays = suspensionDays,
                Status = ViolationStatus.Issued,
                IssuedByUserId = adminUserId,
                RfidTagIdAtIssue = user.RfidTagId,
                AppealDeadline = now.AddDays(Math.Max(MinimumAppealDays, windowDays)),
                CreatedAt = now,
                UpdatedAt = now
            };

            await _violations.AddAsync(violation, ct);
            await _violations.SaveAsync(ct);

            // The suspension is scheduled for the end of the rule's window, so
            // it bites at the same moment the violation turns Accountable. A
            // rule with no window suspends at once.
            var suspensionStartsAt = isImmediate ? (DateTime?)null : now.AddDays(windowDays);

            if (suspensionType != SuspensionType.None)
            {
                ApplySuspension(user, suspensionType, suspensionDays, suspensionStartsAt);
                _users.Update(user);
                await _users.SaveAsync(ct);
            }

            // No fine yet. It is raised when the violation becomes Accountable,
            // so a violation that is dismissed or appealed successfully never
            // shows up as money owed.
            var suspensionNote = (suspensionType, isImmediate) switch
            {
                (SuspensionType.None, _) => string.Empty,

                // Immediate: say so plainly, and say the appeal is still open.
                // Somebody whose card has already stopped working will assume
                // otherwise, and that assumption is what stops them appealing.
                (SuspensionType.Permanent, true) =>
                    " Your RFID access has been suspended, effective now.",
                (SuspensionType.Temporary, true) =>
                    $" Your RFID access has been suspended for {suspensionDays} day(s), effective now.",

                (SuspensionType.Permanent, false) =>
                    $" Your RFID access will be suspended on {suspensionStartsAt:MMM d}. Appeal before then and it is put on hold until a decision is made.",
                (SuspensionType.Temporary, false) =>
                    $" Your RFID access will be suspended for {suspensionDays} day(s) starting {suspensionStartsAt:MMM d}. Appeal before then and it is put on hold until a decision is made.",
            };

            var penaltyNote = violation.PenaltyAmount > 0
                ? $" If it stands, a penalty of ₱{violation.PenaltyAmount:0.00} applies."
                : string.Empty;

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Violation,
                $"Violation: {rule.Title}",
                $"A violation has been issued to you.{penaltyNote}{suspensionNote} You can appeal until {violation.AppealDeadline:MMM d}. Open the app to view details or appeal.",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Violation issued.", violationId = violation.Id });
        }

        // GET /api/violations
        public Task<ActionResult<ViolationListResponse>> GetMyViolationsAsync(Guid userId, int page, int pageSize, CancellationToken ct)
            => ListViolationsAsync(_db.Set<Violation>().AsNoTracking().Where(v => v.UserId == userId), page, pageSize, ct);

        // GET /api/violations/{id}
        public Task<ActionResult<ViolationDetailResponse>> GetMyViolationDetailAsync(Guid userId, Guid violationId, CancellationToken ct)
            => GetViolationDetailAsync(v => v.Id == violationId && v.UserId == userId, forAdmin: false, ct);

        // GET /api/admin/violations
        public Task<ActionResult<ViolationListResponse>> ListAllAsync(
            string? status, string? search, Guid? userId, Guid? ruleId,
            int page, int pageSize, CancellationToken ct)
        {
            var query = _db.Set<Violation>().AsNoTracking();

            if (!string.IsNullOrWhiteSpace(status) && Enum.TryParse<ViolationStatus>(status, true, out var parsedStatus))
                query = query.Where(v => v.Status == parsedStatus);

            if (userId is not null)
                query = query.Where(v => v.UserId == userId);

            if (ruleId is not null)
                query = query.Where(v => v.PolicyRuleId == ruleId);

            // One box for every way an admin knows a person: their name, their
            // student number, or the tag number off the card in their hand.
            if (!string.IsNullOrWhiteSpace(search))
            {
                var term = search.Trim().ToLower();
                query = query.Where(v =>
                    v.User.FullName.ToLower().Contains(term) ||
                    (v.User.StudentNumber != null && v.User.StudentNumber.ToLower().Contains(term)) ||
                    (v.User.RfidTagId != null && v.User.RfidTagId.ToLower().Contains(term)) ||
                    (v.RfidTagIdAtIssue != null && v.RfidTagIdAtIssue.ToLower().Contains(term)));
            }

            return ListViolationsAsync(query, page, pageSize, ct);
        }

        // GET /api/admin/violations/{id}
        public Task<ActionResult<ViolationDetailResponse>> GetDetailForAdminAsync(Guid violationId, CancellationToken ct)
            => GetViolationDetailAsync(v => v.Id == violationId, forAdmin: true, ct);

        // PUT /api/admin/violations/{id}/dismiss
        public async Task<ActionResult<object>> DismissAsync(
            Guid violationId, Guid adminUserId, ViolationReasonDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Reason))
                return new BadRequestObjectResult(new { message = "A reason is required to dismiss a violation." });

            var violation = await _violations.FindAsync(v => v.Id == violationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            // Accountable and Appealed are decided cases. Dismissing one would
            // quietly undo a decision that the user was already told about.
            if (violation.Status is not (ViolationStatus.Issued or ViolationStatus.PendingAppeal))
                return new BadRequestObjectResult(new { message = "Only an Issued or Pending Appeal violation can be dismissed." });

            var now = DateTime.UtcNow;
            violation.Status = ViolationStatus.Dismissed;
            violation.DismissedAt = now;
            violation.DismissedByUserId = adminUserId;
            violation.DismissReason = dto.Reason.Trim();
            violation.UpdatedAt = now;
            _violations.Update(violation);

            // A waiting appeal has nothing left to decide. Left Pending, it sat
            // in the appeals queue forever.
            var appeal = await _appeals.FindAsync(
                a => a.ViolationId == violationId && a.Status == AppealStatus.Pending, ct);
            if (appeal is not null)
            {
                appeal.Status = AppealStatus.Dismissed;
                appeal.DecidedByUserId = adminUserId;
                appeal.DecidedAt = now;
                appeal.AdminNotes = violation.DismissReason;
                _appeals.Update(appeal);
            }

            await _violations.SaveAsync(ct);

            await LiftSuspensionIfNothingElseHoldsAsync(violation, ct);

            // There should be no fine before Accountable; this only cleans up
            // one raised under the old process.
            await _paymentService.WaiveForViolationAsync(violationId, ct);

            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                "Violation dismissed",
                $"A violation on your record has been dismissed. No penalty applies. Reason: {violation.DismissReason}",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Violation dismissed." });
        }

        // PUT /api/admin/violations/{id}/accountable
        public async Task<ActionResult<object>> MakeAccountableAsync(
            Guid violationId, Guid adminUserId, ViolationReasonDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Reason))
                return new BadRequestObjectResult(new { message = "A reason is required." });

            var violation = await _violations.FindAsync(v => v.Id == violationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            // Not while an appeal is waiting: that has to be read and rejected,
            // not skipped over.
            if (violation.Status != ViolationStatus.Issued)
                return new BadRequestObjectResult(new { message = "Only an Issued violation can be made accountable directly." });

            var revoked = await MarkAccountableAsync(
                violation, $"Marked by admin: {dto.Reason.Trim()}", adminUserId, startSuspensionNow: true, ct);

            return new OkObjectResult(new
            {
                message = revoked
                    ? "User is now accountable. This was their third accountable violation, so their RFID card was revoked."
                    : "User is now accountable."
            });
        }

        // Run by ViolationDeadlineService.
        public async Task<int> PromoteLapsedAsync(DateTime now, CancellationToken ct)
        {
            var lapsed = await _db.Set<Violation>()
                .Where(v => v.Status == ViolationStatus.Issued && v.AppealDeadline <= now)
                .OrderBy(v => v.AppealDeadline)
                .ToListAsync(ct);

            // The suspension was scheduled at issue to start at the end of the
            // rule's window, so it is already in force — only the case closes.
            foreach (var violation in lapsed)
                await MarkAccountableAsync(violation, "Appeal deadline passed", null, startSuspensionNow: false, ct);

            return lapsed.Count;
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

            // The deadline job may not have run yet; the deadline is still the deadline.
            if (DateTime.UtcNow > violation.AppealDeadline)
                return new BadRequestObjectResult(new { message = "The appeal period for this violation has ended." });

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

            violation.Status = ViolationStatus.PendingAppeal;
            violation.UpdatedAt = DateTime.UtcNow;
            _violations.Update(violation);

            await _appeals.SaveAsync(ct);

            // The point of the appeal window: appeal inside it and the card
            // keeps working until somebody has actually read the objection.
            //
            // Only while it has not started. Appeal after the suspension has
            // bitten and it stays in force — otherwise a late appeal would be a
            // way to switch the penalty off on demand.
            var now = DateTime.UtcNow;
            if (violation.SuspensionType != SuspensionType.None)
            {
                var user = await _users.FindAsync(u => u.Id == userId, ct);
                if (user is not null
                    && RfidAccess.IsSuspensionPending(user, now)
                    && !await HasOtherSuspendingViolationAsync(userId, violationId, now, ct))
                {
                    RfidAccess.Reactivate(user, now);
                    _users.Update(user);
                    await _users.SaveAsync(ct);
                }
            }

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
                    PolicyRuleTitle = a.Violation.PolicyRule.Title,
                    UserFullName = a.Violation.User.FullName,
                    RfidTagId = a.Violation.RfidTagIdAtIssue ?? a.Violation.User.RfidTagId,
                    ViolationStatus = a.Violation.Status.ToString(),
                    ReasonText = a.ReasonText,
                    Status = a.Status.ToString(),
                    AdminNotes = a.AdminNotes,
                    CreatedAt = a.CreatedAt,
                    DecidedAt = a.DecidedAt
                })
                .ToListAsync(ct);

            // One query for the whole page rather than one per appeal, then the
            // signed URLs. Storage is asked for a URL per file, which is why
            // this cannot be part of the projection above.
            var appealIds = appeals.Select(a => a.AppealId).ToList();
            var evidence = await _db.Set<AppealEvidence>().AsNoTracking()
                .Where(e => appealIds.Contains(e.AppealId))
                .OrderBy(e => e.UploadedAt)
                .ToListAsync(ct);

            var urlsByAppeal = new Dictionary<Guid, List<string>>();
            foreach (var item in evidence)
            {
                if (!urlsByAppeal.TryGetValue(item.AppealId, out var urls))
                    urlsByAppeal[item.AppealId] = urls = [];

                urls.Add(await _fileStorage.GetFileUrlAsync(item.StoragePath, ct));
            }

            foreach (var appeal in appeals)
            {
                if (urlsByAppeal.TryGetValue(appeal.AppealId, out var urls))
                    appeal.EvidenceUrls = urls;
            }

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
            // Rejecting means the user stays punished; they are owed the reason.
            if (!dto.Approve && string.IsNullOrWhiteSpace(dto.AdminNotes))
                return new BadRequestObjectResult(new { message = "A reason is required to reject an appeal." });

            var appeal = await _appeals.FindAsync(a => a.Id == appealId, ct);
            if (appeal is null)
                return new NotFoundObjectResult(new { message = "Appeal not found." });

            if (appeal.Status != AppealStatus.Pending)
                return new BadRequestObjectResult(new { message = "This appeal has already been decided." });

            var violation = await _violations.FindAsync(v => v.Id == appeal.ViolationId, ct);
            if (violation is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            if (violation.Status != ViolationStatus.PendingAppeal)
                return new BadRequestObjectResult(new { message = "This violation is no longer waiting on an appeal." });

            var notes = string.IsNullOrWhiteSpace(dto.AdminNotes) ? null : dto.AdminNotes.Trim();
            var now = DateTime.UtcNow;

            appeal.Status = dto.Approve ? AppealStatus.Approved : AppealStatus.Denied;
            appeal.AdminNotes = notes;
            appeal.DecidedByUserId = adminUserId;
            appeal.DecidedAt = now;
            _appeals.Update(appeal);

            if (!dto.Approve)
            {
                await _appeals.SaveAsync(ct);

                // Submitting the appeal lifted the pending suspension. Losing
                // it puts it back, and it starts now rather than on the
                // original date, which by the time an appeal has been read is
                // usually in the past.
                var revoked = await MarkAccountableAsync(
                    violation, $"Appeal rejected: {notes}", adminUserId, startSuspensionNow: true, ct);

                return new OkObjectResult(new
                {
                    message = revoked
                        ? "Appeal rejected. This was the user's third accountable violation, so their RFID card was revoked."
                        : "Appeal rejected. The user is now accountable."
                });
            }

            violation.Status = ViolationStatus.Appealed;
            violation.UpdatedAt = now;
            _violations.Update(violation);
            await _appeals.SaveAsync(ct);

            await LiftSuspensionIfNothingElseHoldsAsync(violation, ct);
            await _paymentService.WaiveForViolationAsync(violation.Id, ct);

            // An appeal the user never hears back on is worse than no appeal.
            var noteText = notes is null ? "" : $" Note: {notes}";
            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                "Appeal approved",
                $"Your appeal was approved. The violation has been cleared and no penalty applies.{noteText}",
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return new OkObjectResult(new { message = "Appeal accepted. The violation is cleared." });
        }

        // ---------- Helpers ----------

        /// <summary>
        /// The appeal window a rule gets when nobody has chosen one — see
        /// <see cref="PolicyRule.AppealWindowDays"/>, which is where the real
        /// value lives and where an admin can set it to zero for a rule that
        /// has to stop somebody today.
        /// </summary>
        public const int DefaultAppealWindowDays = 3;

        /// <summary>
        /// Closes a case against the user: status, timestamps, the fine, the
        /// suspension if asked, the three-strike check, and the notice. The one
        /// path every route to Accountable goes through, so none of them can
        /// forget a step.
        /// </summary>
        /// <param name="actorUserId">The admin responsible, or null when the deadline lapsed.</param>
        /// <param name="startSuspensionNow">
        /// True when the suspension should bite from now — a rejected appeal
        /// (submitting it lifted the scheduled one) or an admin cutting the
        /// window short. False when the scheduled suspension already started.
        /// </param>
        /// <returns>True if this cost the user their RFID card.</returns>
        private async Task<bool> MarkAccountableAsync(
            Violation violation, string reason, Guid? actorUserId, bool startSuspensionNow, CancellationToken ct)
        {
            var now = DateTime.UtcNow;
            violation.Status = ViolationStatus.Accountable;
            violation.AccountableAt = now;
            violation.AccountableByUserId = actorUserId;
            violation.AccountableReason = reason;
            violation.UpdatedAt = now;
            _violations.Update(violation);
            await _violations.SaveAsync(ct);

            var user = await _users.FindAsync(u => u.Id == violation.UserId, ct);

            if (user is not null && startSuspensionNow && violation.SuspensionType != SuspensionType.None)
            {
                ApplySuspension(user, violation.SuspensionType, violation.SuspensionDays);
                _users.Update(user);
                await _users.SaveAsync(ct);
            }

            // The fine exists from here on, never before.
            var hasFine = violation.PenaltyAmount > 0
                && !await _db.Set<PaymentTransaction>().AnyAsync(p => p.ViolationId == violation.Id, ct);
            if (hasFine)
                await _paymentService.CreateForViolationAsync(violation, ct);

            var revoked = user is not null && await EnforceStrikesAsync(user, violation, actorUserId, ct);

            var parts = new List<string> { "You are accountable for this violation." };
            if (violation.PenaltyAmount > 0)
                parts.Add($"A penalty of ₱{violation.PenaltyAmount:0.00} is now due.");
            if (violation.SuspensionType != SuspensionType.None && !revoked
                && user?.RfidStatus != RfidStatus.Revoked)
                parts.Add("Your RFID access is suspended as the rule requires.");
            if (reason.StartsWith("Appeal rejected"))
                parts.Insert(0, "Your appeal was reviewed and the violation stands.");

            await _notificationService.NotifyUserAsync(
                violation.UserId,
                NotificationType.Violation,
                "Violation upheld",
                string.Join(' ', parts),
                new Dictionary<string, string> { ["violationId"] = violation.Id.ToString() },
                ct);

            return revoked;
        }

        /// <summary>
        /// Revokes the user's RFID card once they have
        /// <see cref="StrikesBeforeRevoke"/> Accountable violations, whatever
        /// rules those were.
        /// </summary>
        /// <remarks>
        /// Counts Accountable only — never a violation still open to appeal —
        /// so nobody loses their card over a case they could yet win. Since
        /// Accountable is final, the count never goes back down. A user with no
        /// card has nothing to take and is skipped.
        /// </remarks>
        private async Task<bool> EnforceStrikesAsync(User user, Violation trigger, Guid? actorUserId, CancellationToken ct)
        {
            var strikes = await _db.Set<Violation>()
                .CountAsync(v => v.UserId == user.Id && v.Status == ViolationStatus.Accountable, ct);

            if (strikes < StrikesBeforeRevoke)
                return false;

            if (!await _adminUsers.RevokeForViolationLimitAsync(user, actorUserId ?? Guid.Empty, ct))
                return false;

            trigger.RfidRevokedAt = DateTime.UtcNow;
            _violations.Update(trigger);
            await _db.SaveChangesAsync(ct);

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Violation,
                "RFID card revoked",
                $"You now have {strikes} accountable violations, so your RFID card has been revoked. Please see the parking office.",
                new Dictionary<string, string> { ["violationId"] = trigger.Id.ToString() },
                ct);

            return true;
        }

        /// <param name="startsAt">
        /// When the suspension begins. Null means immediately.
        /// </param>
        private static void ApplySuspension(
            User user, SuspensionType suspensionType, int? suspensionDays, DateTime? startsAt = null)
        {
            // A revoked user has no card to suspend, and writing Suspended over
            // Revoked would hide why they lost access.
            if (user.RfidStatus == RfidStatus.Revoked)
                return;

            var now = DateTime.UtcNow;
            var effectiveFrom = startsAt ?? now;

            user.RfidStatus = RfidStatus.Suspended;
            user.RfidSuspendedFrom = startsAt;
            // Counted from the day it starts, not the day it was issued —
            // otherwise the appeal window would eat the suspension it precedes,
            // and a 3-day penalty inside a 3-day window would never be served.
            user.RfidSuspendedUntil = suspensionType == SuspensionType.Temporary
                ? effectiveFrom.AddDays(suspensionDays!.Value)
                : null;
            user.UpdatedAt = now;
        }

        /// <summary>
        /// Lifts the suspension a cleared violation carried — unless another
        /// violation is still holding the card.
        /// </summary>
        /// <remarks>
        /// Dismiss used to lift it unconditionally, so dismissing one violation
        /// unlocked a card that a different one had legitimately locked.
        /// </remarks>
        private async Task LiftSuspensionIfNothingElseHoldsAsync(Violation violation, CancellationToken ct)
        {
            if (violation.SuspensionType == SuspensionType.None)
                return;

            var now = DateTime.UtcNow;
            if (await HasOtherSuspendingViolationAsync(violation.UserId, violation.Id, now, ct))
                return;

            var user = await _users.FindAsync(u => u.Id == violation.UserId, ct);
            if (user is null || user.RfidStatus != RfidStatus.Suspended)
                return;

            RfidAccess.Reactivate(user, now);
            _users.Update(user);
            await _users.SaveAsync(ct);
        }

        /// <summary>
        /// Whether any other violation still justifies keeping this user
        /// suspended.
        /// </summary>
        /// <remarks>
        /// An Issued one always does (its suspension is scheduled or running).
        /// An Accountable one does while its suspension could still be running:
        /// permanent, or temporary and not yet served. A served one does not —
        /// otherwise one old, finished suspension would keep every later
        /// lifted one in force.
        /// </remarks>
        private async Task<bool> HasOtherSuspendingViolationAsync(
            Guid userId, Guid exceptViolationId, DateTime now, CancellationToken ct)
        {
            var others = await _db.Set<Violation>().AsNoTracking()
                .Where(v => v.UserId == userId
                         && v.Id != exceptViolationId
                         && v.SuspensionType != SuspensionType.None
                         && (v.Status == ViolationStatus.Issued || v.Status == ViolationStatus.Accountable))
                .Select(v => new { v.Status, v.SuspensionType, v.SuspensionDays, v.AccountableAt })
                .ToListAsync(ct);

            return others.Any(v =>
                v.Status == ViolationStatus.Issued
                || v.SuspensionType == SuspensionType.Permanent
                || (v.AccountableAt ?? now).AddDays(v.SuspensionDays ?? 0) > now);
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
                    PolicyRuleId = v.PolicyRuleId,
                    PolicyRuleTitle = v.PolicyRule.Title,
                    UserId = v.UserId,
                    UserFullName = v.User.FullName,
                    StudentNumber = v.User.StudentNumber,
                    // The card it was issued against, not whatever the user
                    // holds now — a revoked card would otherwise blank the history.
                    RfidTagId = v.RfidTagIdAtIssue ?? v.User.RfidTagId,
                    AppealDeadline = v.AppealDeadline,
                    Status = v.Status.ToString(),
                    PenaltyAmount = v.PenaltyAmount,
                    SuspensionType = v.SuspensionType.ToString(),
                    SuspensionDays = v.SuspensionDays,
                    CreatedAt = v.CreatedAt
                })
                .ToListAsync(ct);

            // The penalty and the violation live in separate tables, and until this
            // was joined up the app had no way to know a fine had been settled: it
            // showed every violation as outstanding forever and counted it against
            // the user's standing long after they had paid.
            //
            // Loaded as a second query keyed by the ids just fetched rather than as
            // a correlated subquery, which is the shape the appeal lookup below
            // already uses and keeps this to two round trips instead of one per row.
            var violationIds = violations.Select(v => v.ViolationId).ToList();
            var penalties = await _db.Set<PaymentTransaction>().AsNoTracking()
                .Where(p => p.ViolationId != null && violationIds.Contains(p.ViolationId.Value))
                .Select(p => new { ViolationId = p.ViolationId!.Value, p.Status, p.PaidAt })
                .ToListAsync(ct);

            var penaltyByViolation = penalties.ToDictionary(p => p.ViolationId);

            foreach (var violation in violations)
            {
                if (!penaltyByViolation.TryGetValue(violation.ViolationId, out var penalty))
                    continue;

                violation.PaymentStatus = penalty.Status.ToString();
                violation.PaidAt = penalty.PaidAt;
            }

            return new OkObjectResult(new ViolationListResponse
            {
                Violations = violations,
                TotalCount = totalCount,
                Page = page,
                PageSize = pageSize
            });
        }

        private async Task<ActionResult<ViolationDetailResponse>> GetViolationDetailAsync(
            System.Linq.Expressions.Expression<Func<Violation, bool>> predicate, bool forAdmin, CancellationToken ct)
        {
            var row = await _db.Set<Violation>().AsNoTracking()
                .Where(predicate)
                .Include(v => v.PolicyRule)
                .Include(v => v.User)
                .FirstOrDefaultAsync(ct);

            if (row is null)
                return new NotFoundObjectResult(new { message = "Violation not found." });

            var violation = new ViolationDetailResponse
            {
                ViolationId = row.Id,
                PolicyRuleTitle = row.PolicyRule.Title,
                Description = row.Description,
                PenaltyAmount = row.PenaltyAmount,
                SuspensionType = row.SuspensionType.ToString(),
                SuspensionDays = row.SuspensionDays,
                Status = row.Status.ToString(),
                CreatedAt = row.CreatedAt,
                UpdatedAt = row.UpdatedAt,
                AppealDeadline = row.AppealDeadline,
                Rule = ToRuleResponse(row.PolicyRule),
                UserId = row.UserId,
                UserFullName = row.User.FullName,
                StudentNumber = row.User.StudentNumber,
                RfidTagId = row.User.RfidTagId,
                RfidTagIdAtIssue = row.RfidTagIdAtIssue,
                RfidStatus = row.User.RfidStatus.ToString(),
                AccountableAt = row.AccountableAt,
                AccountableReason = row.AccountableReason,
                DismissedAt = row.DismissedAt,
                DismissReason = row.DismissReason,
                RfidRevokedAt = row.RfidRevokedAt
            };

            violation.AccountableCount = await _db.Set<Violation>()
                .CountAsync(v => v.UserId == row.UserId && v.Status == ViolationStatus.Accountable, ct);

            // Same join as the list, for the same reason — plus the amount and the
            // deadline, because this is the screen someone opens to find out what
            // they still owe and by when.
            var penalty = await _db.Set<PaymentTransaction>().AsNoTracking()
                .FirstOrDefaultAsync(p => p.ViolationId == violation.ViolationId, ct);

            if (penalty is not null)
            {
                violation.PaymentId = penalty.Id;
                violation.PaymentStatus = penalty.Status.ToString();
                violation.PaidAt = penalty.PaidAt;
                violation.AmountDue = penalty.AmountDue;
                violation.PaymentDueAt = penalty.DueAt;
            }

            var appeal = await _db.Set<ViolationAppeal>().AsNoTracking()
                .Where(a => a.ViolationId == violation.ViolationId)
                .FirstOrDefaultAsync(ct);

            if (appeal is not null)
            {
                violation.AppealId = appeal.Id;
                violation.AppealCreatedAt = appeal.CreatedAt;
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

            // Who did what is for the admin timeline. The user sees what
            // happened and when, not which staff member pressed the button.
            if (forAdmin)
            {
                var actorIds = new[]
                    {
                        (Guid?)row.IssuedByUserId, row.AccountableByUserId,
                        row.DismissedByUserId, appeal?.DecidedByUserId
                    }
                    .Where(id => id is not null && id != Guid.Empty)
                    .Select(id => id!.Value)
                    .Distinct()
                    .ToList();

                var names = await _db.Set<User>().AsNoTracking()
                    .Where(u => actorIds.Contains(u.Id))
                    .ToDictionaryAsync(u => u.Id, u => u.FullName, ct);

                string? NameOf(Guid? id) =>
                    id is { } value && names.TryGetValue(value, out var name) ? name : null;

                violation.IssuedByName = NameOf(row.IssuedByUserId);
                violation.AccountableByName = NameOf(row.AccountableByUserId);
                violation.DismissedByName = NameOf(row.DismissedByUserId);
                violation.AppealDecidedByName = NameOf(appeal?.DecidedByUserId);
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
            AppealWindowDays = r.AppealWindowDays,
            IsActive = r.IsActive,
            CreatedAt = r.CreatedAt,
            UpdatedAt = r.UpdatedAt
        };
    }
}
