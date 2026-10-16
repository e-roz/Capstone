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
        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<DocumentVerification> _verifications;
        private readonly IRepository<AdminAuditLog> _auditLogs;
        private readonly IRepository<DocumentRenewal> _renewals;
        private readonly IFileStorageService _fileStorage;
        private readonly IEmailService _emailService;
        private readonly INotificationService _notificationService;

        public AdminRegistrationService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<DocumentVerification> verifications,
            IRepository<AdminAuditLog> auditLogs,
            IRepository<DocumentRenewal> renewals,
            IFileStorageService fileStorage,
            IEmailService emailService,
            INotificationService notificationService)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _verifications = verifications;
            _auditLogs = auditLogs;
            _renewals = renewals;
            _fileStorage = fileStorage;
            _emailService = emailService;
            _notificationService = notificationService;
        }

        // GET /api/admin/registrations?status=Pending|Approved|Rejected
        //
        // Pending is the queue waiting on a decision. Approved and Rejected are
        // the history of that queue: Approved are the applicants who became
        // users, Rejected the ones turned down. Only Pending carries the check
        // summary, since a decision has already been made on the others.
        public async Task<ActionResult<List<PendingRegistrationResponse>>> GetPendingAsync(string? status, CancellationToken ct)
        {
            var queue = status?.Trim().ToLowerInvariant() switch
            {
                "approved" => "Approved",
                "rejected" => "Rejected",
                _ => "Pending"
            };

            var users = queue switch
            {
                "Approved" => await _users.GetAllAsync(
                    u => u.RegistrationStep == RegistrationStep.Completed
                         && u.Role == UserRole.User
                         && (u.AccountStatus == AccountStatus.Active
                             || u.AccountStatus == AccountStatus.Revoked),
                    ct),
                "Rejected" => await _users.GetAllAsync(
                    u => u.RegistrationStep == RegistrationStep.Completed
                         && u.AccountStatus == AccountStatus.Rejected,
                    ct),
                // Fetch users who have completed registration but are pending review.
                _ => await _users.GetAllAsync(
                    u => u.RegistrationStep == RegistrationStep.Completed &&
                         u.AccountStatus == AccountStatus.PendingReview,
                    ct)
            };

            var userIds = users.Select(u => u.Id).ToList();

            // Fetched in two queries rather than per row: the queue is worked from
            // the top and a check summary on every line would otherwise cost one
            // round trip each.
            var withChecks = queue == "Pending" && userIds.Count > 0;

            var verifications = !withChecks
                ? []
                : await _verifications.GetAllAsync(v => userIds.Contains(v.UserId), ct);

            var vehicles = !withChecks
                ? []
                : await _vehicles.GetAllAsync(v => userIds.Contains(v.UserId), ct);

            var byUser = verifications.GroupBy(v => v.UserId)
                .ToDictionary(g => g.Key, g => g.ToList());
            var vehiclesByUser = vehicles.GroupBy(v => v.UserId)
                .ToDictionary(g => g.Key, g => g.ToList());

            // Who decided, and when, comes from the audit log. An applicant who
            // was approved automatically has no Approve row; their last update
            // stands in for the date.
            var decisions = new Dictionary<Guid, List<AdminAuditLog>>();
            var adminNames = new Dictionary<Guid, string>();
            if (queue != "Pending" && userIds.Count > 0)
            {
                var action = queue == "Approved" ? "Approve" : "Reject";
                var logs = await _auditLogs.GetAllAsync(
                    l => userIds.Contains(l.TargetUserId) && l.Action == action, ct);
                decisions = logs.GroupBy(l => l.TargetUserId)
                    .ToDictionary(g => g.Key, g => g.OrderByDescending(l => l.CreatedAt).ToList());

                var adminIds = logs.Select(l => l.AdminUserId).Distinct().ToList();
                if (adminIds.Count > 0)
                    adminNames = (await _users.GetAllAsync(u => adminIds.Contains(u.Id), ct))
                        .ToDictionary(u => u.Id, u => u.FullName);
            }

            var now = DateTime.UtcNow;

            var response = (queue == "Pending"
                    ? users.OrderBy(u => u.UpdatedAt)
                    : users.OrderByDescending(u => u.UpdatedAt))
                .Select(u =>
                {
                    var row = new PendingRegistrationResponse
                    {
                        UserId = u.Id,
                        FullName = u.FullName,
                        Email = u.Email,
                        Affiliation = u.Affiliation.ToString(),
                        CreatedAt = u.CreatedAt,
                        UpdatedAt = u.UpdatedAt,
                        WaitingDays = Math.Max(0, (now.Date - u.UpdatedAt.Date).Days),
                        IsEBike = u.IsEBikeApplicant,
                        EBikeInspectionDeadline = u.EBikeInspectionDeadline
                    };

                    if (queue != "Pending")
                    {
                        decisions.TryGetValue(u.Id, out var made);
                        var last = made?.FirstOrDefault();
                        row.DecidedAt = queue == "Rejected"
                            ? u.RejectedAt ?? last?.CreatedAt ?? u.UpdatedAt
                            : last?.CreatedAt ?? u.UpdatedAt;
                        row.DecidedByName = last is not null && adminNames.TryGetValue(last.AdminUserId, out var by)
                            ? by
                            : null;
                        if (queue == "Rejected")
                        {
                            row.RejectionReason = u.RejectionReason;
                            row.TimesRejected = Math.Max(1, made?.Count ?? 1);
                        }
                        row.ChecksSummary = string.Empty;
                        return row;
                    }

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

                    var flagged = RegistrationChecks.Flagged(checks);
                    row.FlaggedCount = flagged.Count;
                    if (flagged.Count > 0)
                    {
                        row.TopFinding = flagged[0].Title;
                        row.TopFindingSeverity = flagged[0].Severity;
                    }
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
                RegistrationStep = user.RegistrationStep.ToString(),
                AccountStatus = user.AccountStatus.ToString(),
                VerificationStatus = user.VerificationStatus.ToString(),
                RejectionReason = user.RejectionReason,
                RejectedAt = user.RejectedAt,
                RejectionCount = user.RejectionCount,
                CanReapplyAt = user.CanReapplyAt,
                IsDeleted = user.IsDeleted,
                CreatedAt = user.CreatedAt,
                WaitingDays = Math.Max(0, (DateTime.UtcNow.Date - user.UpdatedAt.Date).Days),
                IsEBike = user.IsEBikeApplicant,
                EBikeInspectionDeadline = user.EBikeInspectionDeadline,
                LicenseValidThrough = user.LicenseValidThrough,
                HasPendingRenewal = await _renewals.ExistsAsync(
                    r => r.UserId == userId && r.Status == RenewalStatus.Pending, ct),
                RfidTagId = user.RfidTagId,
                RfidStatus = user.RfidStatus.ToString(),
                RfidSuspendedUntil = user.RfidSuspendedUntil,
                Vehicles = vehicles.Select(v => new VehicleDTO
                {
                    PlateNumber = v.PlateNumber,
                    VehicleType = v.VehicleType.ToString(),
                    Color = v.Color,
                    IsEBike = v.IsEBike,
                    RegistrationValidThrough = v.RegistrationValidThrough,
                    Brand = v.Brand,
                    DistinguishingMarks = v.DistinguishingMarks
                }).ToList(),
                Documents = documentResponses,
                Checks = RegistrationChecks.Build(user, verifications, vehicles, DateTime.UtcNow)
            });
        }

        /// <remarks>
        /// Two things this used to skip, both fixed here rather than left for later:
        ///
        /// The student number and the section were shown to the reviewer throughout
        /// the review screen but never actually written to the account. They are
        /// copied from the latest submission's confirmed values (the same values
        /// already displayed).
        ///
        /// Approving over a checks verdict that still needs attention used to leave
        /// no more of a trace than an "Approve" row in the audit log. It now also
        /// records why on the submission itself, in <see cref="DocumentVerification.OverrideNote"/>
        /// — the same evidence a reviewer six months from now would otherwise have
        /// to reconstruct from a bare log line.
        /// </remarks>
        public async Task<ActionResult<object>> ApproveAsync(Guid userId, Guid adminUserId, ApproveRegistrationDto dto, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var vehicles = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);
            var verifications = await _verifications.GetAllAsync(v => v.UserId == userId, ct);
            var checks = RegistrationChecks.Build(user, verifications, vehicles, DateTime.UtcNow);

            if (checks is not null && checks.Verdict != "Clear" && string.IsNullOrWhiteSpace(dto.OverrideNote))
            {
                return new BadRequestObjectResult(new
                {
                    message = "The checks need a look — add a note explaining why you're approving anyway."
                });
            }

            var latest = verifications.OrderByDescending(v => v.CreatedAt).FirstOrDefault();

            // The unique index would refuse this anyway, with an unhandled database
            // error. Say it properly instead, and before anything on the account
            // has been changed.
            var studentNumber = latest is null
                ? null
                : latest.ConfirmedStudentNumber ?? latest.ExtractedStudentNumber;

            if (!string.IsNullOrWhiteSpace(studentNumber)
                && await _users.ExistsAsync(u => u.Id != userId && u.StudentNumber == studentNumber, ct))
            {
                return new ConflictObjectResult(new
                {
                    message = "Another account already holds this student number. "
                              + "Check the documents before approving, or reject this application."
                });
            }

            var oldStatus = user.AccountStatus.ToString();
            user.AccountStatus = AccountStatus.Active;
            user.VerificationStatus = VerificationStatus.Passed;
            user.RejectionReason = null;
            user.RejectedAt = null;
            user.CanReapplyAt = null;

            if (latest is not null)
            {
                user.StudentNumber = studentNumber;
                user.Section = latest.ConfirmedSection ?? latest.ExtractedSection;
                user.LicenseValidThrough = latest.ConfirmedLicenseExpiry ?? latest.ExtractedLicenseExpiry;

                // Only the most recent submission is marked. A reviewer approving
                // sees the checks for that submission, and that note is what their
                // override note is a reason for.
                if (checks is not null && checks.Verdict != "Clear")
                {
                    latest.WasOverridden = true;
                    latest.OverriddenByUserId = adminUserId;
                    latest.OverriddenAt = DateTime.UtcNow;
                    latest.OverrideNote = dto.OverrideNote!.Trim();
                    _verifications.Update(latest);
                }
            }

            user.UpdatedAt = DateTime.UtcNow;

            await LogActionAsync(adminUserId, userId, "Approve", oldStatus, user.AccountStatus.ToString(), dto.OverrideNote, ct);

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

            // A vehicle whose receipt had no plate carries the temporary one reserved
            // for it when the applicant submitted. It only counts once approved, so
            // this is when they are told to display it.
            var temporary = vehicles.FirstOrDefault(v => TemporaryPlates.IsVehicleTemporary(v.PlateNumber));
            if (temporary is not null)
            {
                await _notificationService.NotifyUserAsync(
                    user.Id,
                    NotificationType.Account,
                    "Temporary plate",
                    $"Your vehicle's temporary plate is {TemporaryPlates.Format(temporary.PlateNumber)}. "
                    + "Display it on your vehicle.",
                    null,
                    ct);
            }

            return new OkObjectResult(new { message = "User approved." });
        }

        /// <summary>
        /// The e-bike counterpart of the document review: the applicant has brought
        /// the e-bike to the office, and the admin records what they saw.
        /// </summary>
        /// <remarks>
        /// An e-bike has no LTO plate or receipt, so what identifies it is what the
        /// admin records here (photos, brand, colour, marks) plus the temporary
        /// plate issued from this method. The size class goes in
        /// <see cref="Vehicle.VehicleType"/>, which is what lets slot allocation,
        /// rates and the gate treat an e-bike like any other vehicle with no special
        /// case.
        ///
        /// Approval is performed by <see cref="ApproveAsync"/> after the vehicle is
        /// saved, so an e-bike is approved by exactly the same code as everything
        /// else. If that refuses (checks need a note, student number clash), the
        /// vehicle stays, and a retry updates it rather than issuing a second plate.
        /// </remarks>
        public async Task<ActionResult<object>> InspectEBikeAsync(
            Guid userId, Guid adminUserId, EBikeInspectionDto dto, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (!user.IsEBikeApplicant)
                return new BadRequestObjectResult(new { message = "This applicant did not register an e-bike." });

            if (user.AccountStatus != AccountStatus.PendingReview || user.RegistrationStep != RegistrationStep.Completed)
                return new BadRequestObjectResult(new { message = "This application is not waiting for an inspection." });

            if (!(dto.LicenseMatchesPerson && dto.SeenInPerson && dto.NoLtoPlate))
                return new BadRequestObjectResult(new { message = "Finish the checklist before approving." });

            if (string.IsNullOrWhiteSpace(dto.Brand))
                return new BadRequestObjectResult(new { message = "Enter the e-bike's brand." });

            if (string.IsNullOrWhiteSpace(dto.Color))
                return new BadRequestObjectResult(new { message = "Enter the e-bike's colour." });

            if (!Enum.TryParse<VehicleType>(dto.SizeClass, true, out var sizeClass) || !Enum.IsDefined(sizeClass))
                return new BadRequestObjectResult(new { message = "Choose the e-bike's size class." });

            var photos = dto.Photos.Where(f => f is { Length: > 0 }).ToList();
            if (photos.Count < 3)
                return new BadRequestObjectResult(new { message = "Take at least three photos: front, side and back." });
            if (photos.Count > 6)
                return new BadRequestObjectResult(new { message = "Send six photos at most." });

            var allowed = new[] { ".jpg", ".jpeg", ".png" };
            foreach (var photo in photos)
            {
                if (!allowed.Contains(Path.GetExtension(photo.FileName).ToLowerInvariant()))
                    return new BadRequestObjectResult(new { message = "Photos must be JPG or PNG." });
                if (photo.Length > 8 * 1024 * 1024)
                    return new BadRequestObjectResult(new { message = "Each photo must not exceed 8MB." });
            }

            var vehicle = (await _vehicles.GetAllAsync(v => v.UserId == userId && v.IsEBike, ct)).FirstOrDefault();
            var isNew = vehicle is null;

            if (vehicle is null)
            {
                vehicle = new Vehicle
                {
                    UserId = userId,
                    IsEBike = true,
                    PlateNumber = await NextTemporaryPlateAsync(ct)
                };
            }

            vehicle.VehicleType = sizeClass;
            vehicle.Color = dto.Color.Trim();
            vehicle.Brand = dto.Brand.Trim();
            vehicle.DistinguishingMarks = string.IsNullOrWhiteSpace(dto.DistinguishingMarks)
                ? null
                : dto.DistinguishingMarks.Trim();

            if (isNew)
                await _vehicles.AddAsync(vehicle, ct);
            else
                _vehicles.Update(vehicle);

            // Each inspection replaces the photo set, so the file holds the photos the
            // admin settled on rather than every attempt.
            var oldPhotos = await _documents.GetAllAsync(
                d => d.UserId == userId && d.Type == DocumentType.EBikePhoto, ct);
            foreach (var old in oldPhotos)
                _documents.Delete(old);

            var photoDocs = new List<Document>();
            foreach (var photo in photos)
            {
                var path = await _fileStorage.SaveFileAsync(userId, DocumentType.EBikePhoto.ToString(), photo, ct);
                photoDocs.Add(new Document
                {
                    Type = DocumentType.EBikePhoto,
                    FileName = Path.GetFileName(path),
                    FilePath = path,
                    UserId = userId
                });
            }
            await _documents.AddRangeAsync(photoDocs, ct);

            await LogActionAsync(
                adminUserId, userId, "EBikeInspection", null,
                vehicle.PlateNumber, $"{vehicle.Brand}, {vehicle.Color}, size {sizeClass}", ct);

            await _users.SaveAsync(ct);

            var approved = await ApproveAsync(
                userId, adminUserId, new ApproveRegistrationDto { OverrideNote = dto.OverrideNote }, ct);

            if (approved.Result is not OkObjectResult)
                return approved;

            await _notificationService.NotifyUserAsync(
                user.Id,
                NotificationType.Account,
                "E-bike registered",
                $"Your e-bike's temporary plate is {FormatTemporaryPlate(vehicle.PlateNumber)}. Display it on your e-bike.",
                null,
                ct);

            return new OkObjectResult(new
            {
                message = "E-bike inspected and approved.",
                plateNumber = vehicle.PlateNumber
            });
        }

        /// <summary>The next free e-bike temporary plate: EB0001, EB0002 and so on.</summary>
        private async Task<string> NextTemporaryPlateAsync(CancellationToken ct)
        {
            var issued = await _vehicles.GetAllAsync(
                v => v.IsEBike && v.PlateNumber.StartsWith(TemporaryPlates.EBikePrefix), ct);

            return TemporaryPlates.Next(TemporaryPlates.EBikePrefix, issued.Select(v => v.PlateNumber));
        }

        /// <summary>Plates are stored without punctuation; the one people read has a dash.</summary>
        private static string FormatTemporaryPlate(string plate) => TemporaryPlates.Format(plate);

        public async Task<ActionResult<object>> RejectAsync(Guid userId, Guid adminUserId, RejectRegistrationDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Reason))
                return new BadRequestObjectResult(new { message = "Rejection reason is required." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var oldStatus = user.AccountStatus.ToString();
            var wasPending = user.AccountStatus == AccountStatus.PendingReview;

            // The vehicle is created when the applicant confirms, before anyone has
            // approved anything, and a plate belongs to one account at a time. Left in
            // place, a refused application would keep holding its plate and block the
            // documents' real owner from registering it.
            //
            // Only for an application still waiting on review. An account that was
            // already active has parking history hanging off its vehicles, which is
            // not this method's to remove. The readings stay on the verification row,
            // so the reviewer's record of what was submitted is intact; re-applying
            // makes the vehicle again from the new receipt.
            if (wasPending)
            {
                var held = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);
                foreach (var vehicle in held)
                    _vehicles.Delete(vehicle);
            }

            user.AccountStatus = AccountStatus.Rejected;
            user.RegistrationStep = RegistrationStep.Completed;
            user.VerificationStatus = VerificationStatus.Failed;
            user.RejectionReason = dto.Reason.Trim();
            user.RejectedAt = DateTime.UtcNow;
            // A rejection is final: no cooldown, and no way back in for this email.
            // A fixable problem is a retake request instead, which is why that exists.
            // Setting CanReapplyAt is what an administrator does to undo a mistaken
            // rejection (ResetReapplyAsync), and nothing else sets it.
            user.CanReapplyAt = null;
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

            return new OkObjectResult(new { message = "User rejected." });
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

            return new OkObjectResult(new { message = "Rejection lifted. User can re-apply now." });
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

            if (user.AccountStatus is AccountStatus.Revoked)
                return new BadRequestObjectResult(new
                {
                    message = "This account has been revoked, so documents cannot be requested."
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
            nameof(DocumentType.License) => "Driver's licence",
            nameof(DocumentType.OfficialReceipt) => "Official receipt",
            nameof(DocumentType.EBikePhoto) => "E-bike photo",
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
