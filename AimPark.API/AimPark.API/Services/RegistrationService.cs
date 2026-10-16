using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using AimPark.API.Sync.Cloud;
using Microsoft.AspNetCore.Mvc;
using System.Security.Cryptography;
using System.Text.Json;

namespace AimPark.API.Services
{
    public class RegistrationService : IRegistrationService
    {
        private const int SessionTtlHours = 24;
        private const int ReapplyCooldownHours = 24;

        // Some documents genuinely cannot be read — a faded photocopy folded down
        // the middle is not the user's fault and no retake fixes it. Try hard, then
        // let them type the values and move on.
        private const int MaxScanAttempts = 3;

        /// <summary>How long an e-bike applicant has to bring the e-bike to the office.</summary>
        public const int EBikeInspectionDays = 7;

        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<DocumentVerification> _verifications;
        private readonly IRepository<RegistrationSession> _sessions;
        private readonly IOtpService _otpService;
        private readonly IEmailService _emailService;
        private readonly IFileStorageService _fileStorage;
        private readonly ITokenService _tokenService;
        private readonly IDocumentExtractionService _extraction;
        private readonly IPreScreeningService _preScreening;
        private readonly GuardPostSignIn _guardPost;
        private readonly DuplicateIdentityGuard _duplicates;
        private readonly IUserActivityLogger _activity;

        public RegistrationService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<DocumentVerification> verifications,
            IRepository<RegistrationSession> sessions,
            IOtpService otpService,
            IEmailService emailService,
            IFileStorageService fileStorage,
            ITokenService tokenService,
            IDocumentExtractionService extraction,
            IPreScreeningService preScreening,
            GuardPostSignIn guardPost,
            DuplicateIdentityGuard duplicates,
            IUserActivityLogger activity)
        {
            _guardPost = guardPost;
            _duplicates = duplicates;
            _activity = activity;
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _verifications = verifications;
            _sessions = sessions;
            _otpService = otpService;
            _emailService = emailService;
            _fileStorage = fileStorage;
            _tokenService = tokenService;
            _extraction = extraction;
            _preScreening = preScreening;
        }



        public async Task<ActionResult<SessionResponse>> InitiateEmailAsync(InitiateEmailDto dto, string? sessionToken, CancellationToken ct)
        {
            if (ValidationHelper.HasEmptyFields(dto.Email))
                return new BadRequestObjectResult(new { message = "Email is required." });

            var email = IdentifierNormalizer.NormalizeEmail(dto.Email);

            if (await _users.ExistsAsync(u => u.Email == email, ct))
            {
                var existing = await _users.FindAsync(u => u.Email == email, ct);

                // An archived account still holds its address, so the person it
                // belonged to cannot register again — and "Email already
                // registered" told them to go and log in to an account that
                // refuses to let them. Only an admin can undo this, so say so.
                if (existing?.IsDeleted == true)
                {
                    return new BadRequestObjectResult(new
                    {
                        message = "This account has been archived by an administrator. "
                                + "Contact the administrator to have it restored."
                    });
                }

                if (existing?.AccountStatus == AccountStatus.Rejected)
                    return RejectedAccountResult<SessionResponse>(existing);
                return new BadRequestObjectResult(new { message = "Email already registered." });
            }

            var sessionResult = await GetOrCreateSessionAsync(sessionToken, ct);
            if (sessionResult.Result is not null)
                return sessionResult.Result;

            var session = sessionResult.Session!;
            if (session.IsLocked)
                return new BadRequestObjectResult(new { message = "Session locked due to too many failed OTP attempts. Please restart registration." });

            var otp = _otpService.GenerateOtp();
            session.Email = email;
            session.OtpHash = _otpService.HashOtp(otp);
            session.LastOtpChannel = OtpChannel.Email;
            session.OtpExpiresAt = DateTime.UtcNow.Add(_otpService.OtpExpiry);
            session.OtpAttempts = 0;

            _sessions.Update(session);
            await _sessions.SaveAsync(ct);
            await _emailService.SendOtpEmailAsync(email, otp, ct);

            return new OkObjectResult(new SessionResponse
            {
                Message = "Email OTP sent.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
        }

        public async Task<ActionResult<SessionResponse>> VerifyEmailAsync(VerifyOtpDto dto, string? sessionToken, CancellationToken ct)
        {
            if (ValidationHelper.HasEmptyFields(dto.Otp))
                return new BadRequestObjectResult(new { message = "OTP is required." });

            var sessionResult = await GetValidSessionAsync(sessionToken, ct);
            if (sessionResult.Result is not null)
                return sessionResult.Result;

            var session = sessionResult.Session!;

            if (session.IsLocked)
                return new BadRequestObjectResult(new { message = "Session locked due to too many failed OTP attempts. Please restart registration." });

            if (string.IsNullOrEmpty(session.OtpHash) || session.OtpExpiresAt is null)
                return new BadRequestObjectResult(new { message = "No OTP pending. Request a new one." });

            if (DateTime.UtcNow > session.OtpExpiresAt)
                return new BadRequestObjectResult(new { message = "OTP expired. Request a new one." });

            if (!_otpService.VerifyOtp(dto.Otp, session.OtpHash))
            {
                session.OtpAttempts++;
                if (session.OtpAttempts >= _otpService.MaxAttempts)
                    session.IsLocked = true;

                _sessions.Update(session);
                await _sessions.SaveAsync(ct);
                return new BadRequestObjectResult(new { message = "Invalid OTP." });
            }

            session.IsEmailVerified = true;
            session.OtpHash = null;
            session.OtpExpiresAt = null;
            session.OtpAttempts = 0;

            _sessions.Update(session);
            await _sessions.SaveAsync(ct);

            return new OkObjectResult(new SessionResponse
            {
                Message = "Email verified. Complete your profile.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
        }

        public async Task<ActionResult<SessionResponse>> ResendOtpAsync(ResendOtpDto dto, string? sessionToken, CancellationToken ct)
        {
            var sessionResult = await GetValidSessionAsync(sessionToken, ct);
            if (sessionResult.Result is not null)
                return sessionResult.Result;

            var session = sessionResult.Session!;

            if (session.IsLocked)
                return new BadRequestObjectResult(new { message = "Session locked due to too many failed OTP attempts. Please restart registration." });

            if (string.IsNullOrEmpty(session.Email))
                return new BadRequestObjectResult(new { message = "Email not set. Initiate email verification first." });

            var otp = _otpService.GenerateOtp();
            session.OtpHash = _otpService.HashOtp(otp);
            session.LastOtpChannel = OtpChannel.Email;
            session.OtpExpiresAt = DateTime.UtcNow.Add(_otpService.OtpExpiry);
            session.OtpAttempts = 0;

            _sessions.Update(session);
            await _sessions.SaveAsync(ct);
            await _emailService.SendOtpEmailAsync(session.Email, otp, ct);

            return new OkObjectResult(new SessionResponse
            {
                Message = "Email OTP resent.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
        }

        public async Task<ActionResult<CompleteProfileResponse>> CompleteProfileAsync(CompleteProfileDto dto, string? sessionToken, CancellationToken ct)
        {
            if (!dto.AcceptedTerms)
                return new BadRequestObjectResult(new
                {
                    message = "You must accept the terms and conditions to register."
                });

            var sessionResult = await GetValidSessionAsync(sessionToken, ct);
            if (sessionResult.Result is not null)
                return new UnauthorizedObjectResult(new { message = "Invalid or expired session." });

            var session = sessionResult.Session!;

            if (!session.IsEmailVerified || string.IsNullOrEmpty(session.Email))
                return new BadRequestObjectResult(new { message = "Email must be verified before completing profile." });

            if (await _users.ExistsAsync(u => u.Email == session.Email, ct))
                return new BadRequestObjectResult(new { message = "Email already registered." });

            var isOAuth = session.PendingAuthProvider is AuthProvider.Google or AuthProvider.Microsoft;
            if (!isOAuth)
            {
                if (ValidationHelper.HasEmptyFields(dto.Password))
                    return new BadRequestObjectResult(new { message = "Password is required." });

                if (dto.Password.Length < 8 || dto.Password.Length > 128)
                    return new BadRequestObjectResult(new { message = "Password must be between 8 and 128 characters." });
            }

            if (!TryParseAffiliation(dto.Affiliation, out var affiliation))
                return new BadRequestObjectResult(new { message = "Invalid affiliation." });

            // No name is asked for at sign-up. The licence is the one source of it,
            // set when the documents are confirmed. A name an older app version
            // still sends is kept until then.
            var now = DateTime.UtcNow;
            var user = new User
            {
                Id = Guid.NewGuid(),
                FullName = dto.FullName?.Trim() ?? string.Empty,
                Email = session.Email,
                IsEmailVerified = true,
                Affiliation = affiliation,
                PasswordHash = isOAuth || string.IsNullOrWhiteSpace(dto.Password)
                    ? null
                    : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
                AuthProvider = session.PendingAuthProvider ?? AuthProvider.Local,
                ExternalProviderId = session.PendingExternalProviderId,
                Role = UserRole.User,
                // Documents come before the vehicle now: the plate is read off the
                // receipt rather than typed, so there is nothing to ask for until
                // the receipt has been scanned.
                RegistrationStep = RegistrationStep.DocumentUpload,
                AccountStatus = AccountStatus.PendingReview,
                VerificationStatus = VerificationStatus.NotStarted,
                IsFirstLogin = true,
                TermsAcceptedAt = now,
                CreatedAt = now,
                UpdatedAt = now
            };

            await _users.AddAsync(user, ct);
            _sessions.Delete(session);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new CompleteProfileResponse
            {
                Message = "Profile complete. Proceed to vehicle registration.",
                Token = _tokenService.GenerateToken(user, registrationOnly: true)
            });
        }

        public async Task<ActionResult<CompleteProfileResponse>> CompleteProfileForAuthenticatedUserAsync(CompleteProfileDto dto, Guid userId, CancellationToken ct)
        {
            if (!dto.AcceptedTerms)
                return new BadRequestObjectResult(new
                {
                    message = "You must accept the terms and conditions to register."
                });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            // DocumentUpload is allowed as well as ProfileSetup, and that is what
            // makes the first document screen's back arrow lead somewhere. The
            // affiliation set here decides which documents get asked for, so an
            // applicant who picked the wrong one was previously trapped: the
            // form asking for a student registration form could not be left, and
            // this call was the only way to change the answer that produced it.
            //
            // Nothing later than DocumentUpload, though. Once the documents are
            // in, a reviewer is reading a name and an affiliation the submitted
            // papers were checked against, and editing either underneath them
            // would silently invalidate that review.
            if (user.RegistrationStep is not (RegistrationStep.ProfileSetup or RegistrationStep.DocumentUpload))
                return new BadRequestObjectResult(new { message = "Profile setup is not available at the current step." });

            if (!TryParseAffiliation(dto.Affiliation, out var affiliation))
                return new BadRequestObjectResult(new { message = "Invalid affiliation." });

            var affiliationChanged = user.Affiliation != affiliation;

            // The name comes from the licence, so there is nothing to overwrite it
            // with here — a blank keeps the name already on the account rather than
            // erasing it.
            if (!string.IsNullOrWhiteSpace(dto.FullName))
                user.FullName = dto.FullName.Trim();

            user.Affiliation = affiliation;
            user.RegistrationStep = RegistrationStep.DocumentUpload;
            user.TermsAcceptedAt ??= DateTime.UtcNow;

            // A reviewer's retake list names document *kinds*, and which kind
            // proves affiliation is exactly what just changed. Left in place, it
            // would ask for a registration form from someone who is now staff.
            // Clearing it puts them back on a full set, which is the honest
            // answer once the basis for the request no longer holds.
            if (affiliationChanged)
                user.DocumentRetakeJson = null;

            user.UpdatedAt = DateTime.UtcNow;

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new CompleteProfileResponse
            {
                Message = "Profile complete. Please upload your documents.",
                Token = _tokenService.GenerateToken(user, registrationOnly: true)
            });
        }

        /// <summary>
        /// Moves an account off the retired vehicle-first step, if it is sitting on
        /// one.
        /// </summary>
        /// <remarks>
        /// Vehicle details used to be collected before the documents, so accounts
        /// created under that flow can be parked at <see cref="RegistrationStep.VehicleInfo"/>
        /// with no screen left to send them to. They are moved on rather than left
        /// at a dead end.
        ///
        /// The enum member itself stays. It is persisted as an integer, so deleting
        /// it would renumber <see cref="RegistrationStep.DocumentUpload"/> and
        /// silently move every stored account one step backwards.
        /// </remarks>
        private static bool CarryPastRetiredVehicleStep(User user)
        {
            if (user.RegistrationStep != RegistrationStep.VehicleInfo)
                return false;

            user.RegistrationStep = RegistrationStep.DocumentUpload;
            user.UpdatedAt = DateTime.UtcNow;
            return true;
        }

        /// <summary>
        /// Reads one document the moment it is photographed, so the applicant sees
        /// what was read before going on to the next one.
        /// </summary>
        /// <remarks>
        /// Text only: no image, nothing stored, no attempt counted. The phone counts
        /// the tries for each document, and the full scan at the end — images and
        /// all — stays the authority. The same rules run here as there, so a
        /// document that reads cleanly now reads cleanly then.
        /// </remarks>
        public async Task<ActionResult<DocumentReadResponse>> ReadDocumentAsync(
            ReadDocumentDto dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.RegistrationStep is not (RegistrationStep.DocumentUpload or RegistrationStep.VehicleInfo))
                return new BadRequestObjectResult(new { message = "Document upload is not available at the current step." });

            if (!Enum.TryParse<DocumentType>(dto.DocumentType, true, out var type)
                || type is not (DocumentType.Raf or DocumentType.License or DocumentType.OfficialReceipt))
            {
                return new BadRequestObjectResult(new { message = "Unknown document type." });
            }

            var payload = OcrPayloadParser.Parse(dto.Ocr);
            var response = new DocumentReadResponse { DocumentType = type.ToString() };

            var reason = payload is null
                ? ScanFailureReason.NoText
                : OcrCleanup.Diagnose(payload.Lines, type);

            if (reason != ScanFailureReason.None)
            {
                response.Diagnosis = new DocumentDiagnosisDto
                {
                    DocumentType = type.ToString(),
                    Reason = reason.ToString(),
                    Message = OcrCleanup.MessageFor(reason, LabelFor(type))
                };
            }

            var extracted = _extraction.Extract(
                type == DocumentType.Raf ? payload : null,
                type == DocumentType.License ? payload : null,
                type == DocumentType.OfficialReceipt ? payload : null,
                user.FullName);

            response.Extracted = extracted;

            if (MissingValues(extracted, user.Affiliation, [type]).TryGetValue(type, out var labels))
            {
                response.MissingFields = labels;
                response.Diagnosis ??= new DocumentDiagnosisDto
                {
                    DocumentType = type.ToString(),
                    Reason = MissingFieldsReason,
                    Message = $"We couldn't read your {JoinLabels(labels)} on the {LabelFor(type)}. "
                              + "Photograph it again, flat and in good light."
                };
            }

            var today = PhilippineTime.Today();
            response.Expiry = type switch
            {
                DocumentType.License => LicenceExpiryCheck(extracted.LicenseExpiry, today),
                DocumentType.OfficialReceipt => RegistrationExpiryCheck(extracted, today),
                _ => null
            };

            return new OkObjectResult(response);
        }

        private static ExpiryCheckDto LicenceExpiryCheck(DateTime? expiry, DateOnly today)
        {
            var refusal = DocumentExpiryRules.LicenceRefusal(expiry, today);

            return new ExpiryCheckDto
            {
                Field = nameof(ExtractedValuesDto.LicenseExpiry),
                Date = expiry,
                IsExpired = DocumentExpiry.IsExpired(expiry, today),
                Blocks = refusal is not null,
                Message = refusal
            };
        }

        private static ExpiryCheckDto RegistrationExpiryCheck(ExtractedValuesDto extracted, DateOnly today)
        {
            var calculated = IsCalculated(extracted);
            var expired = DocumentExpiry.IsExpired(extracted.RegistrationExpiry, today);
            var refusal = DocumentExpiryRules.RegistrationRefusal(extracted.RegistrationExpiry, calculated, today);

            return new ExpiryCheckDto
            {
                Field = nameof(ExtractedValuesDto.RegistrationExpiry),
                Date = extracted.RegistrationExpiry,
                IsExpired = expired,
                IsCalculated = calculated,
                Blocks = refusal is not null,
                Message = refusal ?? (calculated && expired
                    ? "We worked out this registration's expiry from the plate rather than reading it, "
                      + "and that date has passed. Check it. The admin will too."
                    : null)
            };
        }

        public async Task<ActionResult<ScanResultResponse>> ScanDocumentsAsync(DocumentUploadDTO dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            var carried = CarryPastRetiredVehicleStep(user);

            if (user.RegistrationStep != RegistrationStep.DocumentUpload)
                return new BadRequestObjectResult(new { message = "Document upload is not available at the current step." });

            if (carried)
                _users.Update(user);

            // The vehicle is created from the confirmed values at the end of this
            // flow, so at scan time there is usually nothing here. A re-applying
            // account still has its old one, and keeping the link means the reviewer
            // can see the attempt against the vehicle it was made for.
            var vehicle = await _vehicles.FindAsync(v => v.UserId == userId, ct);

            // Only students send a school document, their RAF. Faculty and staff send
            // their licence and receipt and nothing else: no ID is asked for.
            DocumentType? identityType = user.Affiliation == Affiliation.Student
                ? DocumentType.Raf
                : null;

            // An e-bike has no LTO receipt, so it is never asked for or kept. The
            // account flag covers a reviewer-requested retake, where the app may not
            // repeat the choice the applicant made at the start.
            var isEBike = dto.IsEBike || user.IsEBikeApplicant;

            var allSlots = new List<(IFormFile? File, DocumentType Type, string? Ocr)>();
            if (identityType is { } identity)
                allSlots.Add((dto.IdentityDocument, identity, dto.IdentityDocumentOcr));
            allSlots.Add((dto.License, DocumentType.License, dto.LicenseOcr));
            allSlots.Add((dto.OfficialReceipt, DocumentType.OfficialReceipt, dto.OfficialReceiptOcr));

            var slots = isEBike
                ? allSlots.Where(s => s.Type != DocumentType.OfficialReceipt).ToArray()
                : allSlots.ToArray();

            // What this submission has to contain. A reviewer who asked for one
            // document gets one document; everyone else sends the full set.
            var outstanding = OutstandingRetakeTypes(user, identityType);
            var isRetake = outstanding.Count > 0;
            var required = isRetake ? outstanding : slots.Select(s => s.Type).ToHashSet();

            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
            foreach (var (file, type, _) in slots)
            {
                if (file is null || file.Length == 0)
                {
                    if (required.Contains(type))
                        return new BadRequestObjectResult(new { message = $"{LabelFor(type)} is required." });

                    // Not asked for and not sent. The copy already on file stands.
                    continue;
                }

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"{LabelFor(type)} must be JPG, PNG or PDF." });

                if (file.Length > 8 * 1024 * 1024)
                    return new BadRequestObjectResult(new { message = $"{LabelFor(type)} must not exceed 8MB." });
            }

            // Anything actually sent is processed, including a document the reviewer
            // did not ask for — an applicant who decides to retake a second photo
            // while they have the paperwork out should not be told not to.
            var files = slots.Where(s => s.File is { Length: > 0 }).ToList();

            // Attempts are counted by counting drafts rather than with a column, so
            // the reviewer can see every try and what each one read.
            //
            // A reviewer-requested retake starts the allowance over. The earlier
            // attempts answered a different question and were already accepted;
            // spending someone's last try on a photograph an admin asked for would
            // hand them a document they cannot resubmit.
            var previousAttempts = isRetake
                ? 0
                : (await _verifications.GetAllAsync(v => v.UserId == userId, ct)).Count;
            var triesLeft = Math.Max(0, MaxScanAttempts - previousAttempts - 1);

            var payloads = files.ToDictionary(
                f => f.Type,
                f => OcrPayloadParser.Parse(f.Ocr));

            var diagnostics = new List<DocumentDiagnosisDto>();
            foreach (var (_, type, _) in files)
            {
                // Only what was sent this time. Reporting a stored document as
                // unreadable would send the applicant to retake a photograph this
                // submission never touched.
                var payload = payloads[type];
                if (payload is null)
                    continue;

                var reason = OcrCleanup.Diagnose(payload.Lines, type);
                if (reason == ScanFailureReason.None)
                    continue;

                diagnostics.Add(new DocumentDiagnosisDto
                {
                    DocumentType = type.ToString(),
                    Reason = reason.ToString(),
                    Message = OcrCleanup.MessageFor(reason, LabelFor(type))
                });
            }

            OcrPayloadDto? PayloadFor(DocumentType type)
                => payloads.TryGetValue(type, out var payload) ? payload : null;

            var extracted = _extraction.Extract(
                identityType is { } id ? PayloadFor(id) : null,
                PayloadFor(DocumentType.License),
                PayloadFor(DocumentType.OfficialReceipt),
                user.FullName);

            // A partial submission read only the documents it carried, so every
            // other value came back null. Those are not missing — they were read
            // from documents still on file — and leaving them null would empty the
            // applicant's licence name and expiry because their receipt was blurry.
            if (isRetake)
            {
                var previous = (await _verifications.GetAllAsync(v => v.UserId == userId, ct))
                    .OrderByDescending(v => v.CreatedAt)
                    .FirstOrDefault();

                if (previous is not null)
                    CarryForwardUnreadValues(extracted, previous);
            }

            // A document that read as text can still come back without a value the
            // registration needs. That is a reason to photograph it again, not to
            // let the applicant type the value in: a read value is locked on the
            // summary screen, and the typed one is only offered once the retakes
            // are spent (CanContinue below).
            //
            // Only documents sent this time are asked for again. A reviewer's
            // one-document retake must not send the applicant back to a document
            // they were never asked about.
            var sentTypes = files.Select(f => f.Type).ToHashSet();
            foreach (var (type, labels) in MissingValues(extracted, user.Affiliation, sentTypes))
            {
                if (diagnostics.Any(d => d.DocumentType == type.ToString()))
                    continue;

                diagnostics.Add(new DocumentDiagnosisDto
                {
                    DocumentType = type.ToString(),
                    Reason = MissingFieldsReason,
                    Message = $"We couldn't read your {JoinLabels(labels)} on the {LabelFor(type)}. "
                              + "Photograph it again, flat and in good light."
                });
            }

            // Before anything is stored. The photographed documents say what they
            // say however the form is edited afterwards, so a number that already
            // belongs to another account ends the attempt here — no files kept, no
            // draft row, no attempt spent. The applicant stays on this step.
            var duplicate = await _duplicates.FindAsync(
                userId, "scan",
                [extracted.StudentNumber],
                [extracted.LicenseNumber],
                [extracted.PlateNumber],
                ct);

            if (duplicate is not null)
                return await RefuseDuplicateAsync(user, duplicate, ct);

            // Each scan replaces the stored images, so the reviewer sees the attempt
            // the user actually settled on rather than three sets of photos.
            //
            // Only the types being resubmitted, though. Clearing the lot would mean
            // a reviewer asking for one blurry receipt destroyed the licence and
            // registration form they had already read and accepted.
            var replacing = files.Select(f => f.Type).ToHashSet();
            var existing = await _documents.GetAllAsync(d => d.UserId == userId, ct);
            foreach (var old in existing.Where(d => replacing.Contains(d.Type)))
                _documents.Delete(old);

            var documents = new List<Document>();
            foreach (var (file, type, _) in files)
            {
                // Hashed from the upload itself, before storage rewrites anything, so
                // the value describes what the applicant actually sent.
                var hash = await ComputeSha256Async(file!, ct);
                var filePath = await _fileStorage.SaveFileAsync(userId, type.ToString(), file!, ct);
                documents.Add(new Document
                {
                    Type = type,
                    FileName = Path.GetFileName(filePath),
                    FilePath = filePath,
                    Sha256 = hash,
                    UserId = userId
                });
            }

            await _documents.AddRangeAsync(documents, ct);

            var verification = new DocumentVerification
            {
                UserId = userId,
                VehicleId = vehicle?.Id,
                ExtractedStudentNumber = extracted.StudentNumber,
                ExtractedStudentName = extracted.StudentName,
                ExtractedSection = extracted.Section,
                ExtractedSemester = extracted.Semester,
                ExtractedLicenseName = extracted.LicenseName,
                ExtractedLicenseNumber = extracted.LicenseNumber,
                ExtractedLicenseExpiry = extracted.LicenseExpiry,
                LicenseNameFound = extracted.LicenseNameFound,
                ExtractedPlateNumber = extracted.PlateNumber,
                ExtractedRegistrationExpiry = extracted.RegistrationExpiry,
                RawPayloads = SerializePayloads(payloads),
                Result = VerificationStatus.NotStarted
            };

            await _verifications.AddAsync(verification, ct);
            await _verifications.SaveAsync(ct);

            return new OkObjectResult(new ScanResultResponse
            {
                VerificationId = verification.Id,
                TriesLeft = triesLeft,
                // A retake only helps while something was unreadable and attempts
                // remain. Once they are spent the user types the values instead —
                // a loop repeating "too blurry" on an unreadable document is the
                // worst outcome available.
                CanContinue = diagnostics.Count == 0 || triesLeft <= 0,
                Diagnostics = diagnostics,
                Extracted = extracted
            });
        }

        public async Task<ActionResult<object>> ConfirmDocumentsAsync(ConfirmDocumentsDto dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            CarryPastRetiredVehicleStep(user);

            if (user.RegistrationStep != RegistrationStep.DocumentUpload)
                return new BadRequestObjectResult(new { message = "Document confirmation is not available at the current step." });

            var verification = await _verifications.FindAsync(
                v => v.Id == dto.VerificationId && v.UserId == userId, ct);

            if (verification is null)
                return new NotFoundObjectResult(new { message = "That submission was not found. Please scan your documents again." });

            var isEBike = dto.IsEBike || user.IsEBikeApplicant;

            // An e-bike's type and colour are recorded by the admin at inspection,
            // with the e-bike in front of them, so nothing about the vehicle is asked
            // for here.
            var vehicleType = VehicleType.Motorcycle;
            if (!isEBike)
            {
                if (string.IsNullOrWhiteSpace(dto.VehicleType))
                    return new BadRequestObjectResult(new { message = "Please choose whether this is a car or a motorcycle." });

                if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out vehicleType))
                    return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

                if (string.IsNullOrWhiteSpace(dto.Color))
                    return new BadRequestObjectResult(new { message = "Please choose the vehicle's colour." });
            }

            verification.ConfirmedStudentNumber = FuzzyText.TrimValue(dto.StudentNumber);
            verification.ConfirmedStudentName = FuzzyText.TrimValue(dto.StudentName);
            verification.ConfirmedSection = FuzzyText.TrimValue(dto.Section);
            verification.ConfirmedSemester = FuzzyText.TrimValue(dto.Semester);
            verification.ConfirmedLicenseName = FuzzyText.TrimValue(dto.LicenseName);
            verification.ConfirmedLicenseExpiry = dto.LicenseExpiry;

            var committedLicense = IdentifierNormalizer.NormalizeLicenseNumber(dto.LicenseNumber);
            verification.ConfirmedLicenseNumber = committedLicense.Length == 0 ? null : committedLicense;
            // Null rather than empty when the client sent no plate. Every reader of
            // this column takes a value to mean "the applicant committed to this",
            // and an empty string is not one — it silently outranked the server's
            // own reading in the coalesce below.
            var committedPlate = IdentifierNormalizer.NormalizePlate(dto.PlateNumber);
            verification.ConfirmedPlateNumber = committedPlate.Length == 0 ? null : committedPlate;
            verification.ConfirmedRegistrationExpiry = dto.RegistrationExpiry;

            // An expired licence or registration stops registration here, before
            // anything is saved, instead of reaching a reviewer only to be rejected.
            // The app already showed the applicant the date it read and let them
            // correct a misread; this is the server's own copy of that rule, so a
            // modified app cannot skip it. A registration expiry worked out from the
            // plate rather than read never blocks: the reviewer's check shows it.
            var today = PhilippineTime.Today();
            var payloadsForChecks = DeserializePayloads(verification.RawPayloads);

            var expiredRefusal = DocumentExpiryRules.LicenceRefusal(
                verification.ConfirmedLicenseExpiry ?? verification.ExtractedLicenseExpiry, today);

            if (expiredRefusal is null && !isEBike)
            {
                var registrationExpiry =
                    verification.ConfirmedRegistrationExpiry ?? verification.ExtractedRegistrationExpiry;

                expiredRefusal = DocumentExpiryRules.RegistrationRefusal(
                    registrationExpiry,
                    IsCalculatedRegistrationExpiry(payloadsForChecks, registrationExpiry),
                    today);
            }

            if (expiredRefusal is not null)
                return new BadRequestObjectResult(new { message = expiredRefusal });

            // What was read is checked as well as what was typed. The paper still
            // says what it says, so editing the form does not move the number off
            // the original owner — and the typed value covers the case where
            // nothing could be read at all.
            var duplicate = await _duplicates.FindAsync(
                userId, "confirm",
                [verification.ExtractedStudentNumber, verification.ConfirmedStudentNumber],
                [verification.ExtractedLicenseNumber, verification.ConfirmedLicenseNumber],
                [verification.ExtractedPlateNumber, verification.ConfirmedPlateNumber],
                ct);

            if (duplicate is not null)
                return await RefuseDuplicateAsync(user, duplicate, ct);

            // Counted here for the same reason the scan step counts them: the
            // allowance is what separates "photograph it again" from "this receipt
            // is never going to read, go on without it".
            var attempts = (await _verifications.GetAllAsync(v => v.UserId == userId, ct)).Count;

            Vehicle? vehicle = null;
            string? vehicleNote = null;
            string? refusal = null;

            if (!isEBike)
            {
                (vehicle, vehicleNote, refusal) = await UpsertVehicleFromReceiptAsync(
                    verification, dto, vehicleType, userId, attempts, ct);
            }
            else
            {
                // Set before the checks run, so they know there is no receipt to read.
                user.IsEBikeApplicant = true;
            }

            // Nothing has been saved yet, so returning here leaves the applicant on
            // the confirmation screen with their submission intact.
            if (refusal is not null)
                return new BadRequestObjectResult(new { message = refusal });

            verification.VehicleId = vehicle?.Id;

            // Evaluate rewrites Notes wholesale, so everything else with something to
            // say is added after it rather than before.
            _preScreening.Evaluate(verification, user, vehicle);

            // After the checks, not before. Whatever name the account held when
            // the documents arrived — Google's, or the one from an earlier
            // submission — is what the documents are compared against; set first,
            // a document would be compared with itself and always agree.
            //
            // The licence is the one source of the account's name, for every
            // affiliation. A student's RAF name is only the fallback for a licence
            // whose name could neither be read nor typed.
            var accountName = NameFormat.DisplayName(
                FirstNonBlank(verification.ConfirmedLicenseName, verification.ExtractedLicenseName));

            if (accountName is null && user.Affiliation == Affiliation.Student)
            {
                accountName = NameFormat.DisplayName(
                    FirstNonBlank(verification.ConfirmedStudentName, verification.ExtractedStudentName));
            }

            if (accountName is not null)
                user.FullName = accountName;

            AppendNote(verification, vehicleNote);
            NoteVehicleEdits(verification, dto, user, vehicleType);
            NoteExpiryEdits(verification, payloadsForChecks, isEBike, today);

            // Re-derived here rather than carried over from the scan. These are the
            // submissions that reached a reviewer without the system ever confirming
            // what it was looking at, and that must not have to be inferred from an
            // absence of notes.
            AppendNote(verification, UnconfirmedDocumentsNote(verification));
            AppendNote(verification, await DuplicateDocumentsNoteAsync(userId, ct));

            _verifications.Update(verification);

            user.RegistrationStep = RegistrationStep.Completed;
            user.AccountStatus = AccountStatus.PendingReview;
            user.VerificationStatus = VerificationStatus.ManualReview;

            // Whatever the reviewer asked for has now been supplied. Leaving the
            // request set would send the applicant straight back into the capture
            // flow on their next sign-in, being asked for a photograph they had
            // just taken.
            user.DocumentRetakeJson = null;

            if (isEBike)
            {
                user.EBikeInspectionDeadline = DateTime.UtcNow.AddDays(EBikeInspectionDays);
                user.UpdatedAt = DateTime.UtcNow;
                _users.Update(user);
                await _users.SaveAsync(ct);

                return new OkObjectResult(new
                {
                    message = "Registration submitted. Bring your e-bike and your documents to the admin office "
                              + $"within {EBikeInspectionDays} days to finish.",
                    approved = false,
                    isEBike = true,
                    inspectionDeadline = user.EBikeInspectionDeadline
                });
            }

            var approved = TryAutoApprove(user, verification, vehicle);

            user.UpdatedAt = DateTime.UtcNow;
            _users.Update(user);
            await _users.SaveAsync(ct);

            if (approved)
            {
                await _activity.LogAsync(
                    user.Id, user.Email, UserActivities.AutoApproved,
                    "Every check passed, nothing edited, no duplicates.", ct);
                await _emailService.SendRegistrationApprovedEmailAsync(user.Email, user.FullName, ct);
                return new OkObjectResult(new
                {
                    message = "Registration approved. You can now use your RFID to enter the parking area.",
                    approved = true
                });
            }

            return new OkObjectResult(new { message = "Registration complete. Please wait for admin approval." });
        }

        /// <summary>
        /// Lets a clean application through without a reviewer.
        /// </summary>
        /// <remarks>
        /// "Clean" is decided by <see cref="AutoApprovalPolicy"/> from the same
        /// checks panel a reviewer would have read. The duplicate guard has already
        /// run by the time this does, so what reaches here is also not somebody
        /// else's identifier.
        ///
        /// Only the person fields are copied across, as the admin approval does.
        /// </remarks>
        private bool TryAutoApprove(
            User user, DocumentVerification verification, Vehicle? vehicle)
        {
            if (vehicle is null)
                return false;

            var checks = RegistrationChecks.Build(
                user, [verification], [vehicle], DateTime.UtcNow);

            var studentNumber = verification.ConfirmedStudentNumber ?? verification.ExtractedStudentNumber;
            var licenseNumber = verification.ConfirmedLicenseNumber ?? verification.ExtractedLicenseNumber;

            var identifiersPresent =
                !string.IsNullOrWhiteSpace(licenseNumber)
                && (user.Affiliation != Affiliation.Student || !string.IsNullOrWhiteSpace(studentNumber));

            if (!AutoApprovalPolicy.ShouldAutoApprove(checks, identifiersPresent, Random.Shared.Next(100)))
                return false;

            user.AccountStatus = AccountStatus.Active;
            user.VerificationStatus = VerificationStatus.Passed;
            user.RejectionReason = null;
            user.RejectedAt = null;
            user.CanReapplyAt = null;
            user.StudentNumber = studentNumber;
            user.Section = verification.ConfirmedSection ?? verification.ExtractedSection;
            user.LicenseValidThrough = verification.ConfirmedLicenseExpiry ?? verification.ExtractedLicenseExpiry;

            verification.Result = VerificationStatus.Passed;
            _verifications.Update(verification);
            return true;
        }

        /// <summary>
        /// Ends a scan or confirmation that carries another account's identifier.
        /// </summary>
        /// <remarks>
        /// The applicant is told only that something is already registered. Which
        /// field, and whose account, goes to the activity log for an administrator
        /// — a repeated attempt from one person is the thing worth noticing.
        /// </remarks>
        private async Task<BadRequestObjectResult> RefuseDuplicateAsync(
            User user, DuplicateHit hit, CancellationToken ct)
        {
            await _activity.LogAsync(
                user.Id, user.Email, UserActivities.DuplicateIdentityBlocked,
                $"{hit.Field} at {hit.Step} already belongs to account {hit.HolderUserId}.", ct);

            return new BadRequestObjectResult(new { message = DuplicateIdentityGuard.ApplicantMessage });
        }

        /// <summary>
        /// Says where the applicant changed the vehicle type or colour the receipt gave.
        /// </summary>
        /// <remarks>
        /// Neither is stored as read — only what was confirmed reaches the vehicle —
        /// so the reading is made again from the OCR text kept with the submission.
        /// That avoids a column for two values whose original matters only to the
        /// reviewer, and only once.
        ///
        /// The note's opening words are the markers <see cref="RegistrationChecks"/>
        /// turns into findings, so they must not be reworded without changing it.
        /// </remarks>
        private void NoteVehicleEdits(
            DocumentVerification verification, ConfirmDocumentsDto dto, User user, VehicleType chosenType)
        {
            var payloads = DeserializePayloads(verification.RawPayloads);
            if (payloads.Count == 0)
                return;

            DocumentType? identityType = user.Affiliation == Affiliation.Student
                ? DocumentType.Raf
                : null;

            OcrPayloadDto? PayloadFor(DocumentType type)
                => payloads.TryGetValue(type, out var payload) ? payload : null;

            var read = _extraction.Extract(
                identityType is { } id ? PayloadFor(id) : null,
                PayloadFor(DocumentType.License),
                PayloadFor(DocumentType.OfficialReceipt),
                user.FullName);

            var readType = Enum.TryParse<VehicleType>(read.VehicleType, true, out var parsed)
                ? parsed
                : (VehicleType?)null;

            if (readType is not null && readType != chosenType)
            {
                AppendNote(verification,
                    $"{RegistrationChecks.VehicleTypeEditMarker} — the receipt reads {readType}, the applicant chose {chosenType}.");
            }

            var readColour = read.Color?.Trim();
            var chosenColour = dto.Color?.Trim();

            if (!string.IsNullOrEmpty(readColour)
                && !string.IsNullOrEmpty(chosenColour)
                && !string.Equals(readColour, chosenColour, StringComparison.OrdinalIgnoreCase))
            {
                AppendNote(verification,
                    $"{RegistrationChecks.ColourEditMarker} — the receipt reads \"{readColour}\", the applicant submitted \"{chosenColour}\".");
            }
        }

        /// <summary>
        /// Tells the reviewer where an expiry date was edited or typed in a way
        /// worth checking against the photo.
        /// </summary>
        /// <remarks>
        /// The two cases the expiry block cannot judge on its own: an expired reading
        /// edited into a valid date (a corrected misread, or a lie), and a typed date
        /// that appears nowhere in the photo's text. Both reach review flagged
        /// rather than being refused, because a real misread must not lock anyone out.
        /// </remarks>
        private static void NoteExpiryEdits(
            DocumentVerification verification,
            Dictionary<DocumentType, OcrPayloadDto> payloads,
            bool isEBike,
            DateOnly today)
        {
            AppendNote(verification, DocumentExpiryRules.ExpiredReadingEditedNote(
                "licence", verification.ExtractedLicenseExpiry, verification.ConfirmedLicenseExpiry, today));
            AppendNote(verification, DocumentExpiryRules.TypedDateNotOnPhotoNote(
                "licence expiry", verification.ExtractedLicenseExpiry, verification.ConfirmedLicenseExpiry,
                LinesOf(payloads, DocumentType.License)));

            if (isEBike)
                return;

            AppendNote(verification, DocumentExpiryRules.ExpiredReadingEditedNote(
                "receipt", verification.ExtractedRegistrationExpiry, verification.ConfirmedRegistrationExpiry, today));
            AppendNote(verification, DocumentExpiryRules.TypedDateNotOnPhotoNote(
                "registration expiry", verification.ExtractedRegistrationExpiry, verification.ConfirmedRegistrationExpiry,
                LinesOf(payloads, DocumentType.OfficialReceipt)));
        }

        private static List<OcrLineDto> LinesOf(
            Dictionary<DocumentType, OcrPayloadDto> payloads, DocumentType type)
            => payloads.TryGetValue(type, out var payload) ? OcrCleanup.Prepare(payload.Lines) : [];

        /// <summary>
        /// Whether the registration expiry being submitted is the one the rules
        /// worked out from the plate, rather than one read or typed.
        /// </summary>
        /// <remarks>
        /// Not stored with the submission, so the receipt's OCR text is read again,
        /// the same way <see cref="NoteVehicleEdits"/> recovers the vehicle type.
        /// </remarks>
        private bool IsCalculatedRegistrationExpiry(
            Dictionary<DocumentType, OcrPayloadDto> payloads, DateTime? submitted)
        {
            if (submitted is null || !payloads.TryGetValue(DocumentType.OfficialReceipt, out var receipt))
                return false;

            var read = _extraction.Extract(null, null, receipt, null);

            return IsCalculated(read) && read.RegistrationExpiry?.Date == submitted.Value.Date;
        }

        private static bool IsCalculated(ExtractedValuesDto read) =>
            read.FieldsToCheck.Any(f =>
                f.Field == nameof(ExtractedValuesDto.RegistrationExpiry)
                && f.Reason == nameof(FieldFlag.Derived));

        private static string? FirstNonBlank(params string?[] values)
            => values.FirstOrDefault(v => !string.IsNullOrWhiteSpace(v));

        /// <summary>
        /// Creates or updates the applicant's vehicle from the plate the receipt
        /// gave, plus the type and colour they chose.
        /// </summary>
        /// <remarks>
        /// The gate matches on the plate, so a submission that produces no vehicle
        /// produces an account the barrier will never open for. That used to pass
        /// silently: registration completed, the applicant was told they were done,
        /// and the absence surfaced weeks later as a card that did not work.
        ///
        /// It is now refused, and which of the two causes it is decides how.
        ///
        /// An unreadable receipt is answered with another photograph, so the
        /// applicant is sent back while attempts remain. Once they are spent the
        /// submission goes through without a vehicle, because a receipt too faded
        /// to read is not something a fourth photograph fixes and stranding
        /// somebody at the last step over it is worse than letting them in — they
        /// add the vehicle themselves from My vehicles after approval, where
        /// retakes are unlimited.
        ///
        /// A plate already held by another account is refused outright. No
        /// photograph changes who owns a plate, so there is no retake to offer, and
        /// two accounts claiming one vehicle is a question for a person. Asking it
        /// now is the point: the alternative was approving the second account with
        /// nothing for the gate to match and no way for anyone to notice.
        /// </remarks>
        private async Task<(Vehicle? Vehicle, string? Note, string? Refusal)> UpsertVehicleFromReceiptAsync(
            DocumentVerification verification,
            ConfirmDocumentsDto dto,
            VehicleType vehicleType,
            Guid userId,
            int attempts,
            CancellationToken ct)
        {
            // The user's confirmed value leads now — there is no plate photo left to
            // corroborate the OCR reading, so a correction typed on the confirmation
            // screen is the best evidence available, the same as every other field.
            // NoteUserEdits already flags a change from the OCR reading for the
            // reviewer to check against the receipt image.
            var plate = IdentifierNormalizer.NormalizePlate(verification.ConfirmedPlateNumber);

            if (plate.Length == 0)
                plate = IdentifierNormalizer.NormalizePlate(verification.ExtractedPlateNumber);

            if (plate.Length == 0)
            {
                if (attempts < MaxScanAttempts)
                {
                    return (null, null,
                        "No plate number could be read from your official receipt, so your vehicle "
                        + "could not be registered. Photograph the receipt again, keeping the plate "
                        + "number inside the frame.");
                }

                return (null,
                    "No plate could be read from the receipt after "
                    + $"{MaxScanAttempts} attempts, so no vehicle record was created. "
                    + "The applicant adds the vehicle themselves from My vehicles once approved.",
                    null);
            }

            var existing = await _vehicles.FindAsync(v => v.PlateNumber == plate, ct);

            if (existing is not null && existing.UserId != userId)
            {
                return (null, null,
                    $"Plate {plate} is already registered to another account. If this vehicle is "
                    + "yours, contact the administrator — it cannot be registered twice.");
            }

            var expiry = verification.ConfirmedRegistrationExpiry ?? verification.ExtractedRegistrationExpiry;

            var vehicle = existing ?? new Vehicle { PlateNumber = plate, UserId = userId };

            vehicle.VehicleType = vehicleType;
            vehicle.Color = dto.Color!.Trim();
            vehicle.RegistrationValidThrough = expiry;
            vehicle.RegistrationRenewalMonth = RegistrationRenewal.RenewalMonthFromPlate(plate);

            if (existing is null)
                await _vehicles.AddAsync(vehicle, ct);
            else
                _vehicles.Update(vehicle);

            return (vehicle, null, null);
        }

        /// <summary>
        /// SHA-256 of an uploaded file, as lowercase hex.
        /// </summary>
        private static async Task<string> ComputeSha256Async(IFormFile file, CancellationToken ct)
        {
            await using var stream = file.OpenReadStream();
            var hash = await SHA256.HashDataAsync(stream, ct);
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        /// <summary>
        /// The readings this submission was built from, keyed by document type, for
        /// storage alongside the values they produced.
        /// </summary>
        /// <remarks>
        /// Documents whose phone sent no payload are left out rather than stored as
        /// null, so the presence of a key means "this was read" without a second
        /// column having to say so.
        /// </remarks>
        private static string? SerializePayloads(Dictionary<DocumentType, OcrPayloadDto?> payloads)
        {
            var present = payloads
                .Where(entry => entry.Value is not null)
                .ToDictionary(entry => entry.Key.ToString(), entry => entry.Value);

            return present.Count == 0 ? null : JsonSerializer.Serialize(present);
        }

        private static Dictionary<DocumentType, OcrPayloadDto> DeserializePayloads(string? json)
        {
            var result = new Dictionary<DocumentType, OcrPayloadDto>();

            if (string.IsNullOrWhiteSpace(json))
                return result;

            try
            {
                var stored = JsonSerializer.Deserialize<Dictionary<string, OcrPayloadDto>>(json);
                if (stored is null)
                    return result;

                foreach (var (key, payload) in stored)
                {
                    if (Enum.TryParse<DocumentType>(key, out var type) && payload is not null)
                        result[type] = payload;
                }
            }
            catch (JsonException)
            {
                // Storage this service wrote itself, so a parse failure means the row
                // predates the column or was hand-edited. Neither is worth failing a
                // registration over; the note simply is not produced.
            }

            return result;
        }

        /// <summary>
        /// Names the documents that never showed the printing they should carry.
        /// </summary>
        /// <remarks>
        /// A submission only reaches this point with such a document when the retake
        /// attempts ran out, which is deliberate — nobody is locked out of registering
        /// because a campus prints its form differently. What must not happen is that
        /// it arrives looking like every other submission, so the reviewer is told
        /// plainly, with the count, that the system never recognised the paperwork.
        /// </remarks>
        private static string? UnconfirmedDocumentsNote(DocumentVerification verification)
        {
            var payloads = DeserializePayloads(verification.RawPayloads);
            if (payloads.Count == 0)
                return null;

            var unconfirmed = new List<string>();

            foreach (var (type, payload) in payloads)
            {
                if (!DocumentLandmarks.AppliesTo(type))
                    continue;

                var lines = OcrCleanup.Prepare(payload.Lines);
                if (DocumentLandmarks.LooksGenuine(lines, type))
                    continue;

                unconfirmed.Add($"{LabelFor(type)} ({DocumentLandmarks.CountHits(lines, type)} expected markings found)");
            }

            return unconfirmed.Count == 0
                ? null
                : "Could not confirm these are the documents they were submitted as: "
                  + string.Join("; ", unconfirmed)
                  + ". Check the images by eye before approving.";
        }

        /// <summary>
        /// Reports files here that another account has already submitted.
        /// </summary>
        /// <remarks>
        /// The one check in this system that looks outside a single submission. Every
        /// other comparison asks whether a set of documents agrees with itself, which
        /// a borrowed set does perfectly — so the same photograph turning up under two
        /// accounts is the only automatic signal that documents are being shared.
        ///
        /// Byte equality only. A re-photographed or resaved file will not match, and
        /// that is the accepted limit: this catches forwarding a picture, not someone
        /// who set out to defeat it.
        /// </remarks>
        private async Task<string?> DuplicateDocumentsNoteAsync(Guid userId, CancellationToken ct)
        {
            var mine = await _documents.GetAllAsync(d => d.UserId == userId, ct);

            var hashes = mine
                .Where(d => !string.IsNullOrEmpty(d.Sha256))
                .Select(d => d.Sha256!)
                .Distinct()
                .ToList();

            if (hashes.Count == 0)
                return null;

            var shared = await _documents.GetAllAsync(
                d => d.UserId != userId && d.Sha256 != null && hashes.Contains(d.Sha256), ct);

            if (shared.Count == 0)
                return null;

            var kinds = shared.Select(d => LabelFor(d.Type)).Distinct().ToList();

            return $"Duplicate upload — the {string.Join(" and ", kinds)} here is byte-identical to a file "
                   + "already submitted by a different account.";
        }

        /// <summary>
        /// Adds a line to the reviewer's notes, keeping whatever is already there.
        /// </summary>
        private static void AppendNote(DocumentVerification verification, string? note)
        {
            if (string.IsNullOrWhiteSpace(note))
                return;

            verification.Notes = string.IsNullOrWhiteSpace(verification.Notes)
                ? note
                : verification.Notes + "\n" + note;
        }

        private const string MissingFieldsReason = "MissingFields";

        /// <summary>
        /// The values each submitted document should have given and did not, by
        /// document.
        /// </summary>
        /// <remarks>
        /// Read off the values themselves rather than <see cref="ExtractedValuesDto.FieldsToCheck"/>:
        /// those flags are set before an earlier submission's readings are carried
        /// forward, so they would still call a carried value missing.
        ///
        /// A registration expiry worked out from the plate is not missing — it is
        /// flagged as derived and the applicant glances at it. Only a student has a
        /// school document, so only a registration form can come up short on the
        /// identity side.
        /// </remarks>
        private static Dictionary<DocumentType, List<string>> MissingValues(
            ExtractedValuesDto e, Affiliation affiliation, HashSet<DocumentType> sent)
        {
            var missing = new Dictionary<DocumentType, List<string>>();

            void Check(DocumentType type, bool isMissing, string label)
            {
                if (!isMissing || !sent.Contains(type))
                    return;

                if (!missing.TryGetValue(type, out var labels))
                    missing[type] = labels = [];

                labels.Add(label);
            }

            if (affiliation == Affiliation.Student)
            {
                Check(DocumentType.Raf, string.IsNullOrWhiteSpace(e.StudentNumber), "student number");
                Check(DocumentType.Raf, string.IsNullOrWhiteSpace(e.StudentName), "name");
                Check(DocumentType.Raf, string.IsNullOrWhiteSpace(e.Section), "section");
                Check(DocumentType.Raf, string.IsNullOrWhiteSpace(e.Semester), "term");
            }

            Check(DocumentType.License, string.IsNullOrWhiteSpace(e.LicenseName), "name");
            Check(DocumentType.License, string.IsNullOrWhiteSpace(e.LicenseNumber), "licence number");
            Check(DocumentType.License, e.LicenseExpiry is null, "expiry date");

            Check(DocumentType.OfficialReceipt, string.IsNullOrWhiteSpace(e.PlateNumber), "plate number");
            Check(DocumentType.OfficialReceipt, e.RegistrationExpiry is null, "registration expiry");
            Check(DocumentType.OfficialReceipt, string.IsNullOrWhiteSpace(e.VehicleType), "vehicle type");
            Check(DocumentType.OfficialReceipt, string.IsNullOrWhiteSpace(e.Color), "colour");

            return missing;
        }

        private static string JoinLabels(List<string> labels) => labels.Count switch
        {
            1 => labels[0],
            2 => $"{labels[0]} and {labels[1]}",
            _ => string.Join(", ", labels[..^1]) + " and " + labels[^1]
        };

        private static string LabelFor(DocumentType type) => type switch
        {
            DocumentType.Raf => "registration form",
            DocumentType.License => "driver's licence",
            DocumentType.OfficialReceipt => "official receipt",
            _ => "document"
        };

        public async Task<ActionResult<ReapplyResponse>> ReapplyAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.AccountStatus != AccountStatus.Rejected)
                return new BadRequestObjectResult(new { message = "Re-apply is only available for rejected accounts." });

            // A rejection is final. The only way past it is an administrator lifting
            // it, which is what sets CanReapplyAt.
            if (user.CanReapplyAt is null || DateTime.UtcNow < user.CanReapplyAt)
            {
                return new BadRequestObjectResult(new
                {
                    message = "This registration was rejected and cannot be submitted again. "
                              + "Contact the administrator if you think this is a mistake.",
                    canReapplyAt = user.CanReapplyAt
                });
            }

            user.RegistrationStep = RegistrationStep.DocumentUpload;
            user.AccountStatus = AccountStatus.PendingReview;
            user.VerificationStatus = VerificationStatus.ManualReview;
            user.RejectionReason = null;
            user.RejectedAt = null;
            user.CanReapplyAt = null;
            user.RejectionCount++;
            user.UpdatedAt = DateTime.UtcNow;

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new ReapplyResponse
            {
                Message = "Re-apply accepted. Please re-upload your documents.",
                RegistrationStep = user.RegistrationStep.ToString()
            });
        }

        public async Task<ActionResult<RegistrationStatusResponse>> GetStatusAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            return new OkObjectResult(MapStatus(user));
        }

        // Absent means Student — the overwhelming majority, and the app did not send
        // this field before. An unrecognised value is rejected rather than silently
        // defaulted, since it would decide which documents get asked for.
        private static bool TryParseAffiliation(string? value, out Affiliation affiliation)
        {
            if (string.IsNullOrWhiteSpace(value))
            {
                affiliation = Affiliation.Student;
                return true;
            }

            return Enum.TryParse(value, ignoreCase: true, out affiliation)
                   && Enum.IsDefined(affiliation);
        }

        public async Task<ActionResult<OAuthCallbackResponse>> HandleOAuthCallbackAsync(
            AuthProvider provider,
            string email,
            string externalId,
            string? fullName,
            CancellationToken ct)
        {
            var normalizedEmail = IdentifierNormalizer.NormalizeEmail(email);

            var existing = await _users.FindAsync(u => u.Email == normalizedEmail, ct);
            if (existing is not null)
            {
                if (existing.IsDeleted)
                {
                    return new ObjectResult(new { message = "This account has been deleted. Please contact admin." }) { StatusCode = 403 };
                }

                if (existing.AuthProvider == AuthProvider.Local && existing.PasswordHash is not null)
                {
                    return new ConflictObjectResult(new
                    {
                        message = "An account with this email already exists. Please login with your password."
                    });
                }

                switch (existing.AccountStatus)
                {
                    case AccountStatus.PendingReview:
                        if (existing.RegistrationStep == RegistrationStep.Completed)
                        {
                            return new ObjectResult(new
                            {
                                message = "Your account is waiting for admin approval.",
                                registrationStatus = MapStatus(existing)
                            }) { StatusCode = 403 };
                        }
                        break;

                    case AccountStatus.Rejected:
                        return new ObjectResult(new
                        {
                            message = existing.CanReapplyAt is not null && DateTime.UtcNow < existing.CanReapplyAt
                                ? $"Your registration was rejected. You may re-apply after {existing.CanReapplyAt:O}."
                                : "Your registration was rejected.",
                            rejectionReason = existing.RejectionReason,
                            canReapplyAt = existing.CanReapplyAt,
                            registrationStatus = MapStatus(existing)
                        }) { StatusCode = 403 };

                    case AccountStatus.Revoked:
                        return new ObjectResult(new
                        {
                            message = "Your account has been revoked after three accountable violations.",
                            registrationStatus = MapStatus(existing)
                        }) { StatusCode = 403 };
                }

                if (existing.RegistrationStep == RegistrationStep.Completed
                    && existing.AccountStatus is AccountStatus.Active)
                {
                    if (_guardPost.RefuseIfGuard(existing) is { } guardPost)
                        return guardPost;

                    return new OkObjectResult(new OAuthCallbackResponse
                    {
                        Message = "Login successful.",
                        Token = _tokenService.GenerateToken(existing)
                    });
                }

                return new OkObjectResult(new OAuthCallbackResponse
                {
                    Message = "Resume registration.",
                    Token = _tokenService.GenerateToken(existing, registrationOnly: true)
                });
            }

            var now = DateTime.UtcNow;
            var session = new RegistrationSession
            {
                Id = Guid.NewGuid(),
                Email = normalizedEmail,
                IsEmailVerified = true,
                PendingAuthProvider = provider,
                PendingExternalProviderId = externalId,
                CreatedAt = now,
                ExpiresAt = now.AddHours(SessionTtlHours)
            };

            await _sessions.AddAsync(session, ct);
            await _sessions.SaveAsync(ct);

            if (!string.IsNullOrWhiteSpace(fullName))
            {
                return new OkObjectResult(new OAuthCallbackResponse
                {
                    Message = "Email verified via OAuth. Complete your profile.",
                    SessionToken = _tokenService.GenerateSessionToken(session.Id)
                });
            }

            return new OkObjectResult(new OAuthCallbackResponse
            {
                Message = "Email verified via OAuth. Complete your profile.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
        }

        private async Task<(RegistrationSession? Session, ActionResult<SessionResponse>? Result)> GetValidSessionAsync(
            string? sessionToken,
            CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(sessionToken))
                return (null, new UnauthorizedObjectResult(new { message = "Session token required." }));

            var sessionId = _tokenService.GetSessionIdFromToken(sessionToken);
            if (sessionId is null)
                return (null, new UnauthorizedObjectResult(new { message = "Invalid session token." }));

            var session = await _sessions.FindAsync(s => s.Id == sessionId.Value, ct);
            if (session is null)
                return (null, new UnauthorizedObjectResult(new { message = "Session not found." }));

            if (DateTime.UtcNow > session.ExpiresAt)
                return (null, new UnauthorizedObjectResult(new { message = "Session expired." }));

            return (session, null);
        }

        private async Task<(RegistrationSession Session, ActionResult<SessionResponse>? Result)> GetOrCreateSessionAsync(
            string? sessionToken,
            CancellationToken ct)
        {
            if (!string.IsNullOrWhiteSpace(sessionToken))
            {
                var existing = await GetValidSessionAsync(sessionToken, ct);
                if (existing.Session is not null)
                    return (existing.Session, existing.Result);
                if (existing.Result is not null)
                    return (null!, existing.Result);
            }

            var now = DateTime.UtcNow;
            var session = new RegistrationSession
            {
                Id = Guid.NewGuid(),
                CreatedAt = now,
                ExpiresAt = now.AddHours(SessionTtlHours)
            };

            await _sessions.AddAsync(session, ct);
            await _sessions.SaveAsync(ct);
            return (session, null);
        }

        /// <summary>
        /// The document types a reviewer is waiting on, resolved against the slots
        /// this applicant actually uses. Empty for an ordinary first submission.
        /// </summary>
        /// <remarks>
        /// Only students have a school document, their RAF. A request for the
        /// registration form on a faculty or staff account asks for nothing, rather
        /// than for a document they will never have.
        /// </remarks>
        private static HashSet<DocumentType> OutstandingRetakeTypes(User user, DocumentType? identityType)
        {
            var types = new HashSet<DocumentType>();

            foreach (var item in DocumentRetakes.Read(user.DocumentRetakeJson))
            {
                if (!Enum.TryParse<DocumentType>(item.Type, ignoreCase: true, out var type))
                    continue;

                if (type == DocumentType.Raf)
                {
                    if (identityType is { } identity)
                        types.Add(identity);
                    continue;
                }

                types.Add(type);
            }

            return types;
        }

        /// <summary>
        /// Fills the values this submission could not read from the last one that
        /// could.
        /// </summary>
        /// <remarks>
        /// Only ever fills nulls. A value the new documents did read always wins —
        /// that is the whole reason they were retaken — so this can never quietly
        /// restore the reading the reviewer rejected.
        /// </remarks>
        private static void CarryForwardUnreadValues(ExtractedValuesDto extracted, DocumentVerification previous)
        {
            extracted.StudentNumber ??= previous.ExtractedStudentNumber;
            extracted.StudentName ??= previous.ExtractedStudentName;
            extracted.Section ??= previous.ExtractedSection;
            extracted.Semester ??= previous.ExtractedSemester;
            extracted.LicenseName ??= previous.ExtractedLicenseName;
            extracted.LicenseExpiry ??= previous.ExtractedLicenseExpiry;
            extracted.LicenseNumber ??= previous.ExtractedLicenseNumber;
            extracted.LicenseNameFound ??= previous.LicenseNameFound;
            extracted.PlateNumber ??= previous.ExtractedPlateNumber;
            extracted.RegistrationExpiry ??= previous.ExtractedRegistrationExpiry;
        }

        private static RegistrationStatusResponse MapStatus(User user) => new()
        {
            RegistrationStep = user.RegistrationStep.ToString(),
            AccountStatus = user.AccountStatus.ToString(),
            VerificationStatus = user.VerificationStatus.ToString(),
            RejectionReason = user.RejectionReason,
            CanReapplyAt = user.CanReapplyAt,
            FullName = user.FullName,
            Affiliation = user.Affiliation.ToString(),
            IsEBike = user.IsEBikeApplicant,
            EBikeInspectionDeadline = user.EBikeInspectionDeadline,
            DocumentsToRetake = DocumentRetakes.Read(user.DocumentRetakeJson)
        };

        private static ActionResult<T> RejectedAccountResult<T>(User user)
        {
            if (user.CanReapplyAt is not null && DateTime.UtcNow < user.CanReapplyAt)
            {
                return new BadRequestObjectResult(new
                {
                    message = $"This account was rejected. You may re-apply after {user.CanReapplyAt:O}.",
                    canReapplyAt = user.CanReapplyAt,
                    reason = user.RejectionReason
                });
            }

            return new BadRequestObjectResult(new
            {
                message = "This registration was rejected, so this email cannot be used to register again. "
                          + "Contact the administrator if you think this is a mistake.",
                reason = user.RejectionReason
            });
        }
    }
}
