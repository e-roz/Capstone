using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
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
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly IFileStorageService _fileStorage;
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;

        public AdminRegistrationService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<AdminAuditLog> auditLogs,
            IFileStorageService fileStorage,
            IEmailService emailService,
            INotificationService notificationService)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
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

            var response = users
                .OrderBy(u => u.UpdatedAt)
                .Select(u => new PendingRegistrationResponse
                {
                    UserId = u.Id,
                    FullName = u.FullName,
                    Email = u.Email,
                    CreatedAt = u.CreatedAt,
                    UpdatedAt = u.UpdatedAt
                })
                .ToList();

            return new OkObjectResult(response);
        }

        public async Task<ActionResult<RegistrationDetailResponse>> GetDetailAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var vehicles = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);
            var documents = await _documents.GetAllAsync(d => d.UserId == userId, ct);

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
                Documents = documentResponses
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

        public async Task<ActionResult<object>> ResetStepAsync(Guid userId, Guid adminUserId, ResetRegistrationStepDto dto, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var oldStep = user.RegistrationStep.ToString();
            user.RegistrationStep = dto.Step;
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
