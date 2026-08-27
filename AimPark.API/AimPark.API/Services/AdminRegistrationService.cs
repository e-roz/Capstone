using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;


// CancellationToken is passed to all async methods to tell 
// them to stop processing if the request is cancelled. This is important for long-running operations,
// as it allows the server to free up resources if the client disconnects or cancels the request.
namespace AimPark.API.Services
{
    public class AdminRegistrationService : IAdminRegistrationService
    {
        private const int DefaultReapplyCooldownHours = 24;

        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<DocumentVerification> _verifications;
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly IFileStorageService _fileStorage;
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;

        public AdminRegistrationService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<DocumentVerification> verifications,
            IRepository<AdminAuditLog> auditLogs,
            IFileStorageService fileStorage,
            IEmailService emailService,
            INotificationService notificationService)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _verifications = verifications;
            _auditLogs = auditLogs;
            _fileStorage = fileStorage;
            _emailService = emailService;
            _notificationService = notificationService;
        }

        public async Task<ActionResult<List<PendingRegistrationResponse>>> GetPendingAsync(CancellationToken ct)
        {
            // Fetch users who have completed registration but are pending review. 
            var users = await _users.GetAllAsync(
                u => u.RegistrationStep == RegistrationStep.Completed &&
                     u.AccountStatus == AccountStatus.PendingReview,
                ct);

            var userIds = users.Select(u => u.Id).ToList();

            // Fetched in two queries rather than per row: the queue is worked from
            // the top and a check summary on every line would otherwise cost one
            // round trip each.
            var verifications = userIds.Count == 0
                ? []
                : await _verifications.GetAllAsync(v => userIds.Contains(v.UserId), ct);

            var vehicles = userIds.Count == 0
                ? []
                : await _vehicles.GetAllAsync(v => userIds.Contains(v.UserId), ct);

            var byUser = verifications.GroupBy(v => v.UserId)
                .ToDictionary(g => g.Key, g => g.ToList());
            var vehiclesByUser = vehicles.GroupBy(v => v.UserId)
                .ToDictionary(g => g.Key, g => g.ToList());

            var now = DateTime.UtcNow;

            var response = users
                .OrderBy(u => u.UpdatedAt)
                .Select(u =>
                {
                    var row = new PendingRegistrationResponse
                    {
                        UserId = u.Id,
                        FullName = u.FullName,
                        Email = u.Email,
                        CreatedAt = u.CreatedAt,
                        UpdatedAt = u.UpdatedAt,
                        WaitingDays = Math.Max(0, (now.Date - u.UpdatedAt.Date).Days)
                    };

                    var checks = RegistrationChecks.Build(
                        u,
                        byUser.TryGetValue(u.Id, out var rows) ? rows : [],
                        vehiclesByUser.TryGetValue(u.Id, out var cars) ? cars : [],
                        now);

                    if (checks is null)
                    {
                        row.ChecksSummary = "No documents submitted";
                        return row;
                    }

                    row.ChecksVerdict = checks.Verdict;
                    row.ChecksTotal = checks.Total;
                    row.ChecksNeedingAttention = checks.NeedsAttention;
                    row.ChecksUnreadable = checks.Unreadable;
                    row.ChecksSummary = QueueSummary(checks);
                    return row;
                })
                .ToList();

            return new OkObjectResult(response);
        }

        /// <summary>
        /// The queue's one-line version of the verdict.
        /// </summary>
        /// <remarks>
        /// Shorter than <see cref="RegistrationChecksResponse.Summary"/> on purpose —
        /// this sits inside a table cell, and "all passed" here says only that
        /// nothing contradicted itself, never that the application is safe to
        /// approve.
        /// </remarks>
        private static string QueueSummary(RegistrationChecksResponse checks)
        {
            if (checks.NeedsAttention > 0)
                return checks.NeedsAttention == 1
                    ? "1 needs attention"
                    : $"{checks.NeedsAttention} need attention";

            if (checks.Unreadable > 0)
                return checks.Unreadable == 1 ? "1 unreadable" : $"{checks.Unreadable} unreadable";

            return $"All {checks.Total} passed";
        }

        public async Task<ActionResult<RegistrationDetailResponse>> GetDetailAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var vehicles = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);
            var documents = await _documents.GetAllAsync(d => d.UserId == userId, ct);
            var verifications = await _verifications.GetAllAsync(v => v.UserId == userId, ct);

            var documentResponses = new List<DocumentDetailResponse>();
            foreach (var d in documents)
            {
                documentResponses.Add(new DocumentDetailResponse
                {
                    Id = d.Id,
                    Type = d.Type.ToString(),
                    FileName = d.FileName,
                    FilePath = await _fileStorage.GetFileUrlAsync(d.FilePath, ct),
                    UploadedAt = d.UploadedAt
                });
            }

            return new OkObjectResult(new RegistrationDetailResponse
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                Affiliation = user.Affiliation.ToString(),
                StudentNumber = user.StudentNumber,
                Section = user.Section,
                EnrollmentValidUntil = user.EnrollmentValidUntil,
                RegistrationStep = user.RegistrationStep.ToString(),
                AccountStatus = user.AccountStatus.ToString(),
                VerificationStatus = user.VerificationStatus.ToString(),
                RejectionReason = user.RejectionReason,
                RejectedAt = user.RejectedAt,
                RejectionCount = user.RejectionCount,
                CanReapplyAt = user.CanReapplyAt,
                IsDeleted = user.IsDeleted,
                CreatedAt = user.CreatedAt,
                RfidTagId = user.RfidTagId,
                RfidStatus = user.RfidStatus.ToString(),
                RfidSuspendedUntil = user.RfidSuspendedUntil,
                Vehicles = vehicles.Select(v => new VehicleDTO
                {
                    PlateNumber = v.PlateNumber,
                    VehicleType = v.VehicleType.ToString(),
                    Brand = v.Brand,
                    Model = v.Model,
                    Color = v.Color
                }).ToList(),
                Documents = documentResponses,
                Checks = RegistrationChecks.Build(user, verifications, vehicles, DateTime.UtcNow)
            });
        }

        public async Task<ActionResult<object>> ApproveAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var oldStatus = user.AccountStatus.ToString();
            user.AccountStatus = AccountStatus.Active;
            user.VerificationStatus = VerificationStatus.Passed;
            user.RejectionReason = null;
            user.RejectedAt = null;
            user.CanReapplyAt = null;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Approve", oldStatus, user.AccountStatus.ToString(), null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            await _emailService.SendRegistrationApprovedEmailAsync(user.Email, user.FullName, ct);

            // The email may sit unread; someone waiting on approval is far more
            // likely to be watching the app.
            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Account,
                "Account approved",
                "Your registration has been approved. You can now use your RFID to enter the parking area.",
                null,
                ct);

            return new OkObjectResult(new { message = "User approved." });
        }

        public async Task<ActionResult<object>> RejectAsync(Guid userId, Guid adminUserId, RejectRegistrationDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Reason))
                return new BadRequestObjectResult(new { message = "Rejection reason is required." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var cooldownHours = dto.CooldownHours ?? DefaultReapplyCooldownHours;
            var oldStatus = user.AccountStatus.ToString();

            user.AccountStatus = AccountStatus.Rejected;
            user.RegistrationStep = RegistrationStep.Completed;
            user.VerificationStatus = VerificationStatus.Failed;
            user.RejectionReason = dto.Reason.Trim();
            user.RejectedAt = DateTime.UtcNow;
            user.CanReapplyAt = DateTime.UtcNow.AddHours(cooldownHours);
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Reject", oldStatus, user.AccountStatus.ToString(), dto.Reason, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            await _emailService.SendRegistrationRejectedEmailAsync(user.Email, user.FullName, user.RejectionReason!, ct);

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Account,
                "Registration not approved",
                $"Your registration was not approved. Reason: {user.RejectionReason}",
                null,
                ct);

            return new OkObjectResult(new
            {
                message = "User rejected.",
                canReapplyAt = user.CanReapplyAt
            });
        }

        public async Task<ActionResult<object>> ResetReapplyAsync(Guid userId, Guid adminUserId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var oldValue = user.CanReapplyAt?.ToString("O");
            user.CanReapplyAt = DateTime.UtcNow;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "ResetReapply", oldValue, user.CanReapplyAt?.ToString("O"), null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Re-apply cooldown reset. User can re-apply now." });
        }

        /// <summary>
        /// Sends specific documents back to the applicant instead of refusing
        /// the whole application.
        /// </summary>
        /// <remarks>
        /// Deliberately not a rejection, and the differences are the point.
        ///
        /// The account stays <see cref="AccountStatus.PendingReview"/>: nothing
        /// has been refused, so <c>RejectionCount</c> does not move and no
        /// rejection reason is recorded against a person who was not rejected.
        ///
        /// No cooldown is set. The cooldown on rejection exists to stop someone
        /// resubmitting the same refused application over and over; an applicant
        /// doing precisely what a reviewer asked is the opposite of that, and
        /// making them wait a day to retake one photograph would be the system
        /// punishing them for its own request.
        ///
        /// Moving the step back to <see cref="RegistrationStep.DocumentUpload"/>
        /// is what does the routing: the next sign-in issues a registration-only
        /// token, which the app already knows to follow into the capture flow.
        /// No new client path is needed to get them there.
        /// </remarks>
        public async Task<ActionResult<object>> RequestDocumentRetakeAsync(
            Guid userId, Guid adminUserId, RequestDocumentRetakeDto dto, CancellationToken ct)
        {
            if (!DocumentRetakes.TryNormalize(dto.Documents, out var documents, out var error))
                return new BadRequestObjectResult(new { message = error });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.IsDeleted)
                return new BadRequestObjectResult(new { message = "This account has been deleted." });

            if (user.AccountStatus is AccountStatus.Suspended)
                return new BadRequestObjectResult(new
                {
                    message = "Lift the suspension before asking for documents."
                });

            var oldStep = user.RegistrationStep.ToString();

            user.DocumentRetakeJson = DocumentRetakes.Write(documents);
            user.RegistrationStep = RegistrationStep.DocumentUpload;
            user.AccountStatus = AccountStatus.PendingReview;
            user.VerificationStatus = VerificationStatus.ManualReview;
            user.UpdatedAt = DateTime.UtcNow;

            var summary = string.Join(", ", documents.Select(d => d.Type));

            await LogActionAsync(
                adminUserId, userId, "RequestDocumentRetake", oldStep,
                user.RegistrationStep.ToString(), summary, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            var lines = documents.Select(d => $"{DocumentLabel(d.Type)}: {d.Reason}");
            var body = string.IsNullOrWhiteSpace(dto.Note)
                ? string.Join("\n", lines)
                : $"{dto.Note!.Trim()}\n\n{string.Join("\n", lines)}";

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Account,
                documents.Count == 1
                    ? "One document needs retaking"
                    : $"{documents.Count} documents need retaking",
                body,
                null,
                ct);

            return new OkObjectResult(new
            {
                message = "Documents sent back to the applicant.",
                documents = documents.Select(d => new { d.Type, d.Reason })
            });
        }

        /// <summary>The applicant's own word for a document, not the enum's.</summary>
        private static string DocumentLabel(string type) => type switch
        {
            nameof(DocumentType.Raf) => "Registration form",
            nameof(DocumentType.SchoolId) => "School ID",
            nameof(DocumentType.License) => "Driver's licence",
            nameof(DocumentType.OfficialReceipt) => "Official receipt",
            nameof(DocumentType.PlatePhoto) => "Plate photo",
            _ => type
        };

        public async Task<ActionResult<object>> ResetStepAsync(Guid userId, Guid adminUserId, ResetRegistrationStepDto dto, CancellationToken ct)
        {
            if (!TryParseRegistrationStep(dto.Step, out var step))
                return new BadRequestObjectResult(new
                {
                    message = "Unknown registration step. Expected one of: "
                        + string.Join(", ", Enum.GetNames<RegistrationStep>())
                });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var oldStep = user.RegistrationStep.ToString();
            user.RegistrationStep = step;
            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "ResetStep", oldStep, user.RegistrationStep.ToString(), null, ct);

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new
            {
                message = "Registration step reset.",
                registrationStep = user.RegistrationStep.ToString()
            });
        }

        /// <summary>
        /// Parses a registration step by name, rejecting anything that is not a
        /// real member.
        /// </summary>
        /// <remarks>
        /// The <see cref="Enum.IsDefined{TEnum}(TEnum)"/> check is not
        /// redundant. <see cref="Enum.TryParse{TEnum}(string, bool, out TEnum)"/>
        /// also accepts a *numeric* string and will return true for "99",
        /// handing back a value no member has — which is the same undefined
        /// step this endpoint is being fixed to refuse, arriving by a different
        /// door.
        /// </remarks>
        private static bool TryParseRegistrationStep(string? value, out RegistrationStep step)
        {
            return Enum.TryParse(value, ignoreCase: true, out step)
                && Enum.IsDefined(step);
        }

        private async Task LogActionAsync(
            Guid adminUserId,
            Guid targetUserId,
            string action,
            string? oldValue,
            string? newValue,
            string? reason,
            CancellationToken ct)
        {
            await _auditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = targetUserId,
                Action = action,
                OldValue = oldValue,
                NewValue = newValue,
                Reason = reason,
                CreatedAt = DateTime.UtcNow
            }, ct);
        }
    }
}
