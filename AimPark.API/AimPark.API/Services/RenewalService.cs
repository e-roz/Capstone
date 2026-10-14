using System.Security.Cryptography;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    /// <summary>
    /// Renewing a licence or a vehicle registration after the account is approved.
    /// </summary>
    /// <remarks>
    /// The dates read at registration are a snapshot. Without a way to replace
    /// them, a renewed licence looks expired forever, and an expired one that is
    /// never renewed opens the gate forever. This is the way to replace them, and
    /// it goes through an admin because a date typed or photographed by the person
    /// it benefits is exactly what a reviewer exists to look at.
    ///
    /// Nothing on <see cref="User"/> or <see cref="Vehicle"/> changes until an admin
    /// approves, and <see cref="User.AccountStatus"/> never changes at all.
    /// </remarks>
    public class RenewalService : IRenewalService
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<DocumentRenewal> _renewals;
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly IFileStorageService _fileStorage;
        private readonly IDocumentExtractionService _extraction;
        private readonly INotificationService _notifications;

        public RenewalService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<DocumentRenewal> renewals,
            IRepository<AdminAuditLog> auditLogs,
            IFileStorageService fileStorage,
            IDocumentExtractionService extraction,
            INotificationService notifications)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _renewals = renewals;
            _auditLogs = auditLogs;
            _fileStorage = fileStorage;
            _extraction = extraction;
            _notifications = notifications;
        }

        // ── The user's side ──────────────────────────────────────────────────

        public async Task<ActionResult<RenewalScanResponse>> ScanAsync(
            RenewalUploadDto dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.AccountStatus != AccountStatus.Active)
                return new BadRequestObjectResult(new
                {
                    message = "Your account must be approved before renewing a document."
                });

            if (!TryParseKind(dto.Kind, out var kind))
                return new BadRequestObjectResult(new { message = "Choose what you are renewing." });

            Vehicle? vehicle = null;
            if (kind == DocumentType.OfficialReceipt)
            {
                if (dto.VehicleId is null)
                    return new BadRequestObjectResult(new { message = "Choose which vehicle this registration is for." });

                vehicle = await _vehicles.FindAsync(v => v.Id == dto.VehicleId && v.UserId == userId, ct);
                if (vehicle is null)
                    return new NotFoundObjectResult(new { message = "Vehicle not found." });

                if (vehicle.IsEBike)
                    return new BadRequestObjectResult(new
                    {
                        message = "An e-bike has no registration to renew."
                    });
            }

            var label = LabelFor(kind);
            var file = dto.Document;
            if (file is null || file.Length == 0)
                return new BadRequestObjectResult(new { message = $"The {label} photo is required." });

            var allowed = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
            if (!allowed.Contains(Path.GetExtension(file.FileName).ToLowerInvariant()))
                return new BadRequestObjectResult(new { message = $"The {label} must be JPG, PNG or PDF." });

            if (file.Length > 8 * 1024 * 1024)
                return new BadRequestObjectResult(new { message = $"The {label} must not exceed 8MB." });

            var vehicleId = vehicle?.Id;

            // One renewal at a time per document. A second photograph while the
            // first is waiting would let someone queue several and have the admin
            // pick whichever date suits.
            var existing = await _renewals.GetAllAsync(
                r => r.UserId == userId && r.Type == kind && r.VehicleId == vehicleId
                     && (r.Status == RenewalStatus.Draft || r.Status == RenewalStatus.Pending), ct);

            if (existing.Any(r => r.Status == RenewalStatus.Pending))
                return new BadRequestObjectResult(new
                {
                    message = $"Your {label} is already waiting for review. You can upload again if it is turned down."
                });

            foreach (var draft in existing)
                _renewals.Delete(draft);

            var payload = OcrPayloadParser.Parse(dto.DocumentOcr);

            var diagnostics = new List<DocumentDiagnosisDto>();
            if (payload is not null)
            {
                var reason = OcrCleanup.Diagnose(payload.Lines, kind);
                if (reason != ScanFailureReason.None)
                {
                    diagnostics.Add(new DocumentDiagnosisDto
                    {
                        DocumentType = kind.ToString(),
                        Reason = reason.ToString(),
                        Message = OcrCleanup.MessageFor(reason, label)
                    });
                }
            }

            var extracted = kind == DocumentType.License
                ? _extraction.Extract(null, payload, null, user.FullName)
                : _extraction.Extract(null, null, payload, null);

            DateTime? expiry = kind == DocumentType.License
                ? extracted.LicenseExpiry
                : extracted.RegistrationExpiry;

            // The wrong vehicle's receipt would otherwise extend this vehicle's
            // registration on the strength of a plate the user never named.
            if (vehicle is not null)
            {
                var read = IdentifierNormalizer.NormalizePlate(extracted.PlateNumber);
                var onFile = IdentifierNormalizer.NormalizePlate(vehicle.PlateNumber);

                if (read.Length > 0 && onFile.Length > 0 && read != onFile)
                {
                    diagnostics.Add(new DocumentDiagnosisDto
                    {
                        DocumentType = kind.ToString(),
                        Reason = "PlateMismatch",
                        Message = $"This receipt reads {read}, but the vehicle is {onFile}. "
                                  + "Photograph the receipt for this vehicle."
                    });
                }
            }

            var filePath = await _fileStorage.SaveFileAsync(userId, kind.ToString(), file, ct);
            var document = new Document
            {
                Type = kind,
                FileName = Path.GetFileName(filePath),
                FilePath = filePath,
                Sha256 = await ComputeSha256Async(file, ct),
                UserId = userId
            };
            await _documents.AddAsync(document, ct);

            var renewal = new DocumentRenewal
            {
                UserId = userId,
                VehicleId = vehicleId,
                Type = kind,
                DocumentId = document.Id,
                ExtractedExpiry = expiry,
                Status = RenewalStatus.Draft
            };
            await _renewals.AddAsync(renewal, ct);
            await _renewals.SaveAsync(ct);

            return new OkObjectResult(new RenewalScanResponse
            {
                RenewalId = renewal.Id,
                ExtractedExpiry = expiry,
                CanContinue = diagnostics.Count == 0,
                Diagnostics = diagnostics
            });
        }

        public async Task<ActionResult<object>> SubmitAsync(
            Guid renewalId, SubmitRenewalDto dto, Guid userId, CancellationToken ct)
        {
            var renewal = await _renewals.FindAsync(r => r.Id == renewalId && r.UserId == userId, ct);
            if (renewal is null)
                return new NotFoundObjectResult(new { message = "That renewal was not found." });

            if (renewal.Status != RenewalStatus.Draft)
                return new BadRequestObjectResult(new { message = "This renewal has already been sent." });

            if (dto.Expiry is null)
                return new BadRequestObjectResult(new { message = "Enter the new expiry date." });

            var expiry = dto.Expiry.Value.Date;

            // A renewed document that still shows a past date has not been renewed,
            // and a date no later than the one on file is the same document again.
            if (expiry < DateTime.UtcNow.Date)
                return new BadRequestObjectResult(new
                {
                    message = "That date has already passed. Upload the renewed document, not the old one."
                });

            var current = await CurrentExpiryAsync(renewal, ct);
            if (current is not null && expiry <= current.Value.Date)
                return new BadRequestObjectResult(new
                {
                    message = "That is not later than the expiry already on file. Check you photographed the renewed document."
                });

            renewal.NewExpiry = expiry;
            renewal.Status = RenewalStatus.Pending;
            renewal.CreatedAt = DateTime.UtcNow;
            _renewals.Update(renewal);
            await _renewals.SaveAsync(ct);

            return new OkObjectResult(new
            {
                message = "Sent for review. Your access stays as it is until an admin approves it."
            });
        }

        public async Task<ActionResult<List<RenewalResponse>>> GetMineAsync(Guid userId, CancellationToken ct)
        {
            var all = await _renewals.GetAllAsync(
                r => r.UserId == userId && r.Status != RenewalStatus.Draft, ct);
            var vehicles = (await _vehicles.GetAllAsync(v => v.UserId == userId, ct))
                .ToDictionary(v => v.Id);

            // The newest answer per document. An approved one means there is
            // nothing outstanding; a rejected one is shown until a new one replaces it.
            var latest = all
                .GroupBy(r => (r.Type, r.VehicleId))
                .Select(g => g.OrderByDescending(r => r.CreatedAt).First())
                .Where(r => r.Status is RenewalStatus.Pending or RenewalStatus.Rejected)
                .OrderByDescending(r => r.CreatedAt)
                .Select(r => new RenewalResponse
                {
                    Id = r.Id,
                    Kind = r.Type.ToString(),
                    VehicleId = r.VehicleId,
                    PlateNumber = r.VehicleId is { } id && vehicles.TryGetValue(id, out var v) ? v.PlateNumber : null,
                    Status = r.Status.ToString(),
                    NewExpiry = r.NewExpiry,
                    RejectReason = r.RejectReason,
                    CreatedAt = r.CreatedAt
                })
                .ToList();

            return new OkObjectResult(latest);
        }

        // ── The admin's side ─────────────────────────────────────────────────

        public async Task<ActionResult<List<AdminRenewalResponse>>> GetForAdminAsync(
            string? status, CancellationToken ct)
        {
            var wanted = status?.Trim().ToLowerInvariant() switch
            {
                "approved" => RenewalStatus.Approved,
                "rejected" => RenewalStatus.Rejected,
                _ => RenewalStatus.Pending
            };

            var renewals = await _renewals.GetAllAsync(r => r.Status == wanted, ct);
            if (renewals.Count == 0)
                return new OkObjectResult(new List<AdminRenewalResponse>());

            var userIds = renewals.Select(r => r.UserId).Distinct().ToList();
            var users = (await _users.GetAllAsync(u => userIds.Contains(u.Id), ct)).ToDictionary(u => u.Id);
            var vehicles = (await _vehicles.GetAllAsync(v => userIds.Contains(v.UserId), ct)).ToDictionary(v => v.Id);

            var docIds = renewals.Select(r => r.DocumentId).ToList();
            var docs = (await _documents.GetAllAsync(d => docIds.Contains(d.Id), ct)).ToDictionary(d => d.Id);

            var reviewerIds = renewals.Where(r => r.ReviewedByUserId != null)
                .Select(r => r.ReviewedByUserId!.Value).Distinct().ToList();
            var reviewers = reviewerIds.Count == 0
                ? new Dictionary<Guid, User>()
                : (await _users.GetAllAsync(u => reviewerIds.Contains(u.Id), ct)).ToDictionary(u => u.Id);

            var rows = new List<AdminRenewalResponse>();
            foreach (var r in renewals)
            {
                if (!users.TryGetValue(r.UserId, out var user))
                    continue;

                docs.TryGetValue(r.DocumentId, out var doc);
                Vehicle? vehicle = null;
                if (r.VehicleId is { } vid)
                    vehicles.TryGetValue(vid, out vehicle);

                rows.Add(new AdminRenewalResponse
                {
                    Id = r.Id,
                    UserId = r.UserId,
                    FullName = user.FullName,
                    Email = user.Email,
                    Kind = r.Type.ToString(),
                    VehicleId = r.VehicleId,
                    PlateNumber = vehicle?.PlateNumber,
                    Status = r.Status.ToString(),
                    CurrentExpiry = r.Type == DocumentType.License
                        ? user.LicenseValidThrough
                        : vehicle?.RegistrationValidThrough,
                    ExtractedExpiry = r.ExtractedExpiry,
                    NewExpiry = r.NewExpiry,
                    FileName = doc?.FileName ?? string.Empty,
                    FileUrl = doc is null ? string.Empty : await _fileStorage.GetFileUrlAsync(doc.FilePath, ct),
                    RejectReason = r.RejectReason,
                    ReviewedByName = r.ReviewedByUserId is { } rid && reviewers.TryGetValue(rid, out var by)
                        ? by.FullName
                        : null,
                    ReviewedAt = r.ReviewedAt,
                    CreatedAt = r.CreatedAt
                });
            }

            // The queue is worked oldest first; the history, newest first.
            return new OkObjectResult(wanted == RenewalStatus.Pending
                ? rows.OrderBy(r => r.CreatedAt).ToList()
                : rows.OrderByDescending(r => r.ReviewedAt ?? r.CreatedAt).ToList());
        }

        public async Task<ActionResult<object>> ApproveAsync(Guid renewalId, Guid adminUserId, CancellationToken ct)
        {
            var renewal = await _renewals.FindAsync(r => r.Id == renewalId, ct);
            if (renewal is null)
                return new NotFoundObjectResult(new { message = "Renewal not found." });

            if (renewal.Status != RenewalStatus.Pending || renewal.NewExpiry is null)
                return new BadRequestObjectResult(new { message = "This renewal is not waiting for review." });

            var user = await _users.FindAsync(u => u.Id == renewal.UserId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            string? oldValue;
            string what;

            if (renewal.Type == DocumentType.License)
            {
                oldValue = user.LicenseValidThrough?.ToString("O");
                user.LicenseValidThrough = renewal.NewExpiry;
                user.UpdatedAt = DateTime.UtcNow;
                _users.Update(user);
                what = "driver's licence";
            }
            else
            {
                var vehicle = await _vehicles.FindAsync(v => v.Id == renewal.VehicleId, ct);
                if (vehicle is null)
                    return new NotFoundObjectResult(new { message = "That vehicle no longer exists." });

                oldValue = vehicle.RegistrationValidThrough?.ToString("O");
                vehicle.RegistrationValidThrough = renewal.NewExpiry;
                _vehicles.Update(vehicle);
                what = $"registration for {vehicle.PlateNumber}";
            }

            renewal.Status = RenewalStatus.Approved;
            renewal.ReviewedByUserId = adminUserId;
            renewal.ReviewedAt = DateTime.UtcNow;
            renewal.RejectReason = null;
            _renewals.Update(renewal);

            await _auditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = renewal.UserId,
                Action = "RenewalApprove",
                OldValue = oldValue,
                NewValue = renewal.NewExpiry?.ToString("O"),
                Reason = what,
                CreatedAt = DateTime.UtcNow
            }, ct);

            await _renewals.SaveAsync(ct);

            await _notifications.NotifyUserAsync(
                user.Id,
                NotificationType.Account,
                "Renewal approved",
                $"Your {what} is updated to {renewal.NewExpiry:MMMM d, yyyy}.",
                null,
                ct);

            return new OkObjectResult(new { message = "Renewal approved." });
        }

        public async Task<ActionResult<object>> RejectAsync(
            Guid renewalId, Guid adminUserId, RejectRenewalDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Reason))
                return new BadRequestObjectResult(new { message = "Give a reason so the user knows what to fix." });

            var renewal = await _renewals.FindAsync(r => r.Id == renewalId, ct);
            if (renewal is null)
                return new NotFoundObjectResult(new { message = "Renewal not found." });

            if (renewal.Status != RenewalStatus.Pending)
                return new BadRequestObjectResult(new { message = "This renewal is not waiting for review." });

            renewal.Status = RenewalStatus.Rejected;
            renewal.ReviewedByUserId = adminUserId;
            renewal.ReviewedAt = DateTime.UtcNow;
            renewal.RejectReason = dto.Reason.Trim();
            _renewals.Update(renewal);

            await _auditLogs.AddAsync(new AdminAuditLog
            {
                Id = Guid.NewGuid(),
                AdminUserId = adminUserId,
                TargetUserId = renewal.UserId,
                Action = "RenewalReject",
                OldValue = null,
                NewValue = renewal.NewExpiry?.ToString("O"),
                Reason = renewal.RejectReason,
                CreatedAt = DateTime.UtcNow
            }, ct);

            await _renewals.SaveAsync(ct);

            await _notifications.NotifyUserAsync(
                renewal.UserId,
                NotificationType.Account,
                "Renewal not accepted",
                $"Your {LabelFor(renewal.Type)} was not accepted. {renewal.RejectReason}",
                null,
                ct);

            return new OkObjectResult(new { message = "Renewal rejected." });
        }

        // ── Helpers ──────────────────────────────────────────────────────────

        private async Task<DateTime?> CurrentExpiryAsync(DocumentRenewal renewal, CancellationToken ct)
        {
            if (renewal.Type == DocumentType.License)
                return (await _users.FindAsync(u => u.Id == renewal.UserId, ct))?.LicenseValidThrough;

            return (await _vehicles.FindAsync(v => v.Id == renewal.VehicleId, ct))?.RegistrationValidThrough;
        }

        private static bool TryParseKind(string? value, out DocumentType kind)
        {
            kind = default;
            if (!Enum.TryParse<DocumentType>(value, ignoreCase: true, out var parsed))
                return false;

            if (parsed is not (DocumentType.License or DocumentType.OfficialReceipt))
                return false;

            kind = parsed;
            return true;
        }

        private static string LabelFor(DocumentType type) => type == DocumentType.License
            ? "driver's licence"
            : "vehicle registration";

        private static async Task<string> ComputeSha256Async(IFormFile file, CancellationToken ct)
        {
            await using var stream = file.OpenReadStream();
            var hash = await SHA256.HashDataAsync(stream, ct);
            return Convert.ToHexString(hash).ToLowerInvariant();
        }
    }
}
