using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
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
            IPreScreeningService preScreening)
        {
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
            if (ValidationHelper.HasEmptyFields(dto.FullName))
                return new BadRequestObjectResult(new { message = "Full name is required." });

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

            var now = DateTime.UtcNow;
            var user = new User
            {
                Id = Guid.NewGuid(),
                FullName = dto.FullName.Trim(),
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
            if (ValidationHelper.HasEmptyFields(dto.FullName))
                return new BadRequestObjectResult(new { message = "Full name is required." });

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

            // A RAF only exists for students; everyone else brings a school ID.
            var identityType = user.Affiliation == Affiliation.Student
                ? DocumentType.Raf
                : DocumentType.SchoolId;

            var slots = new[]
            {
                (File: dto.IdentityDocument, Type: identityType, Ocr: dto.IdentityDocumentOcr),
                (File: dto.License, Type: DocumentType.License, Ocr: dto.LicenseOcr),
                (File: dto.OfficialReceipt, Type: DocumentType.OfficialReceipt, Ocr: dto.OfficialReceiptOcr),
                (File: dto.PlatePhoto, Type: DocumentType.PlatePhoto, Ocr: dto.PlatePhotoOcr)
            };

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

            OcrPayloadDto? PayloadFor(DocumentType type)
                => payloads.TryGetValue(type, out var payload) ? payload : null;

            var extracted = _extraction.Extract(
                PayloadFor(identityType),
                PayloadFor(DocumentType.License),
                PayloadFor(DocumentType.OfficialReceipt),
                PayloadFor(DocumentType.PlatePhoto));

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

            var verification = new DocumentVerification
            {
                UserId = userId,
                VehicleId = vehicle?.Id,
                ExtractedStudentNumber = extracted.StudentNumber,
                ExtractedStudentName = extracted.StudentName,
                ExtractedSection = extracted.Section,
                ExtractedSemester = extracted.Semester,
                ExtractedLicenseName = extracted.LicenseName,
                ExtractedLicenseExpiry = extracted.LicenseExpiry,
                ExtractedPlateNumber = extracted.PlateNumber,
                ExtractedRegistrationExpiry = extracted.RegistrationExpiry,
                ExtractedPlatePhotoNumber = extracted.PlatePhotoNumber,
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

            if (string.IsNullOrWhiteSpace(dto.VehicleType))
                return new BadRequestObjectResult(new { message = "Please choose whether this is a car or a motorcycle." });

            if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType))
                return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

            if (string.IsNullOrWhiteSpace(dto.Color))
                return new BadRequestObjectResult(new { message = "Please choose the vehicle's colour." });

            verification.ConfirmedStudentNumber = FuzzyText.TrimValue(dto.StudentNumber);
            verification.ConfirmedStudentName = FuzzyText.TrimValue(dto.StudentName);
            verification.ConfirmedSection = FuzzyText.TrimValue(dto.Section);
            verification.ConfirmedSemester = FuzzyText.TrimValue(dto.Semester);
            verification.ConfirmedLicenseName = FuzzyText.TrimValue(dto.LicenseName);
            verification.ConfirmedLicenseExpiry = dto.LicenseExpiry;
            verification.ConfirmedPlateNumber = IdentifierNormalizer.NormalizePlate(dto.PlateNumber);
            verification.ConfirmedRegistrationExpiry = dto.RegistrationExpiry;

            var (vehicle, vehicleNote) = await UpsertVehicleFromReceiptAsync(verification, dto, vehicleType, userId, ct);
            verification.VehicleId = vehicle?.Id;

            // Evaluate rewrites Notes wholesale, so everything else with something to
            // say is added after it rather than before.
            _preScreening.Evaluate(verification, user, vehicle);

            AppendNote(verification, vehicleNote);

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

            user.UpdatedAt = DateTime.UtcNow;
            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Registration complete. Please wait for admin approval." });
        }

        /// <summary>
        /// Creates or updates the applicant's vehicle from the plate the receipt
        /// gave, plus the type and colour they chose.
        /// </summary>
        /// <remarks>
        /// Two situations produce no vehicle at all, and neither is treated as a
        /// failure the applicant has to solve. If nothing readable came off the
        /// receipt there is no plate to store, and the plate column is unique, so a
        /// blank row would collide with the next applicant in the same position. If
        /// the plate already belongs to someone else, two accounts are claiming one
        /// vehicle and only a person can work out which is right.
        ///
        /// In both cases the registration still completes and the reviewer is told
        /// what is missing, because the alternative — refusing at the final step,
        /// after four photographs — strands the applicant over something they
        /// cannot influence.
        /// </remarks>
        private async Task<(Vehicle? Vehicle, string? Note)> UpsertVehicleFromReceiptAsync(
            DocumentVerification verification,
            ConfirmDocumentsDto dto,
            VehicleType vehicleType,
            Guid userId,
            CancellationToken ct)
        {
            var plate = IdentifierNormalizer.NormalizePlate(
                verification.ConfirmedPlateNumber ?? verification.ExtractedPlateNumber);

            if (plate.Length == 0)
            {
                return (null,
                    "No plate could be read from the receipt, so no vehicle record was created. " +
                    "Add the vehicle by hand when approving, or the gate will have nothing to match.");
            }

            var existing = await _vehicles.FindAsync(v => v.PlateNumber == plate, ct);

            if (existing is not null && existing.UserId != userId)
            {
                return (null,
                    $"Plate {plate} is already registered to another account. No vehicle record was created.");
            }

            var expiry = verification.ConfirmedRegistrationExpiry ?? verification.ExtractedRegistrationExpiry;

            var vehicle = existing ?? new Vehicle { PlateNumber = plate, UserId = userId };

            vehicle.VehicleType = vehicleType;
            vehicle.Color = dto.Color!.Trim();
            vehicle.Brand = dto.Brand?.Trim() ?? string.Empty;
            vehicle.Model = dto.Model?.Trim() ?? string.Empty;
            vehicle.RegistrationValidThrough = expiry;
            vehicle.RegistrationRenewalMonth = RegistrationRenewal.RenewalMonthFromPlate(plate);

            if (existing is null)
                await _vehicles.AddAsync(vehicle, ct);
            else
                _vehicles.Update(vehicle);

            return (vehicle, null);
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

        private static string LabelFor(DocumentType type) => type switch
        {
            DocumentType.Raf => "registration form",
            DocumentType.SchoolId => "school ID",
            DocumentType.License => "driver's licence",
            DocumentType.OfficialReceipt => "official receipt",
            DocumentType.PlatePhoto => "plate photo",
            _ => "document"
        };

        public async Task<ActionResult<ReapplyResponse>> ReapplyAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.AccountStatus != AccountStatus.Rejected)
                return new BadRequestObjectResult(new { message = "Re-apply is only available for rejected accounts." });

            if (user.CanReapplyAt is not null && DateTime.UtcNow < user.CanReapplyAt)
            {
                return new BadRequestObjectResult(new
                {
                    message = $"You may re-apply after {user.CanReapplyAt:O}.",
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

                    case AccountStatus.Suspended:
                        return new ObjectResult(new
                        {
                            message = "Your account has been suspended. Please contact admin.",
                            registrationStatus = MapStatus(existing)
                        }) { StatusCode = 403 };
                }

                if (existing.RegistrationStep == RegistrationStep.Completed && existing.AccountStatus == AccountStatus.Active)
                {
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
        /// The identity slot holds a RAF for a student and a school ID for everyone
        /// else, and a reviewer picking from a list may well name the other one.
        /// Both are folded to whichever this account files under, so a request for
        /// "the registration form" on a staff account asks for their school ID
        /// rather than for a document they will never have.
        /// </remarks>
        private static HashSet<DocumentType> OutstandingRetakeTypes(User user, DocumentType identityType)
        {
            var types = new HashSet<DocumentType>();

            foreach (var item in DocumentRetakes.Read(user.DocumentRetakeJson))
            {
                if (!Enum.TryParse<DocumentType>(item.Type, ignoreCase: true, out var type))
                    continue;

                types.Add(type is DocumentType.Raf or DocumentType.SchoolId ? identityType : type);
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
            extracted.PlateNumber ??= previous.ExtractedPlateNumber;
            extracted.RegistrationExpiry ??= previous.ExtractedRegistrationExpiry;
            extracted.PlatePhotoNumber ??= previous.ExtractedPlatePhotoNumber;
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
                message = "This account was rejected. Contact support for assistance.",
                reason = user.RejectionReason
            });
        }
    }
}
