using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    public class RegistrationService : IRegistrationService
    {
        private const int SessionTtlHours = 24;
        private const int ReapplyCooldownHours = 24;

        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<RegistrationSession> _sessions;
        private readonly IOtpService _otpService;
        private readonly IEmailService _emailService;
        private readonly IFileStorageService _fileStorage;
        private readonly ITokenService _tokenService;

        public RegistrationService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<RegistrationSession> sessions,
            IOtpService otpService,
            IEmailService emailService,
            IFileStorageService fileStorage,
            ITokenService tokenService)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _sessions = sessions;
            _otpService = otpService;
            _emailService = emailService;
            _fileStorage = fileStorage;
            _tokenService = tokenService;
        }

        public async Task<ActionResult<SessionResponse>> InitiatePhoneAsync(InitiatePhoneDto dto, CancellationToken ct)
        {
            var phone = IdentifierNormalizer.NormalizePhone(dto.PhoneNumber);

            if (phone is not null && await _users.ExistsAsync(u => u.PhoneNumber == phone, ct))
            {
                var existing = await _users.FindAsync(u => u.PhoneNumber == phone, ct);
                if (existing?.AccountStatus == AccountStatus.Rejected)
                    return RejectedAccountResult<SessionResponse>(existing);
                return new BadRequestObjectResult(new { message = "Phone number already registered." });
            }

            var now = DateTime.UtcNow;
            var session = new RegistrationSession
            {
                Id = Guid.NewGuid(),
                PhoneNumber = phone,
                IsPhoneVerified = true,
                CreatedAt = now,
                ExpiresAt = now.AddHours(SessionTtlHours)
            };

            await _sessions.AddAsync(session, ct);
            await _sessions.SaveAsync(ct);

            return new OkObjectResult(new SessionResponse
            {
                Message = "Session started. Proceed to email verification.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
        }

        public async Task<ActionResult<SessionResponse>> VerifyPhoneAsync(VerifyOtpDto dto, string? sessionToken, CancellationToken ct)
        {
            var sessionResult = await GetValidSessionAsync(sessionToken, ct);
            if (sessionResult.Result is not null)
                return sessionResult.Result;

            var session = sessionResult.Session!;

            if (!session.IsPhoneVerified)
                session.IsPhoneVerified = true;

            _sessions.Update(session);
            await _sessions.SaveAsync(ct);

            return new OkObjectResult(new SessionResponse
            {
                Message = "Phone step complete. Proceed to email verification.",
                SessionToken = _tokenService.GenerateSessionToken(session.Id)
            });
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

            if (dto.Channel == OtpChannel.Email)
            {
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

            return new BadRequestObjectResult(new { message = "SMS OTP is not supported. Use email OTP." });
        }

        public async Task<ActionResult<CompleteProfileResponse>> CompleteProfileAsync(CompleteProfileDto dto, string? sessionToken, CancellationToken ct)
        {
            if (ValidationHelper.HasEmptyFields(dto.FullName))
                return new BadRequestObjectResult(new { message = "Full name is required." });

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

            var phone = IdentifierNormalizer.NormalizePhone(dto.PhoneNumber ?? session.PhoneNumber);
            if (phone is not null && await _users.ExistsAsync(u => u.PhoneNumber == phone, ct))
                return new BadRequestObjectResult(new { message = "Phone number already registered." });

            var now = DateTime.UtcNow;
            var user = new User
            {
                Id = Guid.NewGuid(),
                FullName = dto.FullName.Trim(),
                Email = session.Email,
                IsEmailVerified = true,
                PhoneNumber = phone,
                IsPhoneVerified = session.IsPhoneVerified && phone is not null,
                PasswordHash = isOAuth || string.IsNullOrWhiteSpace(dto.Password)
                    ? null
                    : BCrypt.Net.BCrypt.HashPassword(dto.Password, workFactor: 12),
                AuthProvider = session.PendingAuthProvider ?? AuthProvider.Local,
                ExternalProviderId = session.PendingExternalProviderId,
                Role = UserRole.User,
                RegistrationStep = RegistrationStep.VehicleInfo,
                AccountStatus = AccountStatus.PendingReview,
                VerificationStatus = VerificationStatus.NotStarted,
                IsFirstLogin = true,
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

        public async Task<ActionResult<object>> RegisterVehicleAsync(VehicleDTO dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.RegistrationStep != RegistrationStep.VehicleInfo)
                return new BadRequestObjectResult(new { message = "Vehicle registration is not available at the current step." });

            if (await _vehicles.ExistsAsync(v => v.UserId == userId, ct))
                return new BadRequestObjectResult(new { message = "Vehicle already registered for this user." });

            if (await _vehicles.ExistsAsync(v => v.PlateNumber == dto.PlateNumber, ct))
                return new BadRequestObjectResult(new { message = "Plate number already registered." });

            if (ValidationHelper.HasEmptyFields(dto.PlateNumber, dto.VehicleType, dto.Brand, dto.Model, dto.Color))
                return new BadRequestObjectResult(new { message = "All vehicle fields are required." });

            var vehicle = new Vehicle
            {
                PlateNumber = dto.PlateNumber,
                VehicleType = dto.VehicleType,
                Brand = dto.Brand,
                Model = dto.Model,
                Color = dto.Color,
                UserId = userId
            };

            user.RegistrationStep = RegistrationStep.DocumentUpload;
            user.UpdatedAt = DateTime.UtcNow;

            await _vehicles.AddAsync(vehicle, ct);
            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Step 2 complete. Please upload your documents." });
        }

        public async Task<ActionResult<object>> RegisterDocumentsAsync(DocumentUploadDTO dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.RegistrationStep != RegistrationStep.DocumentUpload)
                return new BadRequestObjectResult(new { message = "Document upload is not available at the current step." });

            if (!await _vehicles.ExistsAsync(v => v.UserId == userId, ct))
                return new BadRequestObjectResult(new { message = "Please complete vehicle registration first." });

            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
            var files = new[]
            {
                (dto.License, "License"),
                (dto.OR, "OR"),
                (dto.CR, "CR")
            };

            foreach (var (file, type) in files)
            {
                if (file is null || file.Length == 0)
                    return new BadRequestObjectResult(new { message = $"{type} document is required." });

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"{type} must be JPG, PNG or PDF." });

                if (file.Length > 5 * 1024 * 1024)
                    return new BadRequestObjectResult(new { message = $"{type} must not exceed 5MB." });
            }

            var documents = new List<Document>();
            foreach (var (file, type) in files)
            {
                var filePath = await _fileStorage.SaveFileAsync(userId, type, file!, ct);
                documents.Add(new Document
                {
                    Type = type,
                    FileName = Path.GetFileName(filePath),
                    FilePath = filePath,
                    UserId = userId
                });
            }

            await _documents.AddRangeAsync(documents, ct);

            user.RegistrationStep = RegistrationStep.Completed;
            user.AccountStatus = AccountStatus.PendingReview;
            user.VerificationStatus = VerificationStatus.ManualReview;
            user.UpdatedAt = DateTime.UtcNow;
            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Registration complete. Please wait for admin approval." });
        }

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
                if (existing.AuthProvider == AuthProvider.Local && existing.PasswordHash is not null)
                {
                    return new BadRequestObjectResult(new
                    {
                        message = "An account with this email already exists. Please login with your password."
                    });
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
                IsPhoneVerified = true,
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
                IsPhoneVerified = true,
                CreatedAt = now,
                ExpiresAt = now.AddHours(SessionTtlHours)
            };

            await _sessions.AddAsync(session, ct);
            await _sessions.SaveAsync(ct);
            return (session, null);
        }

        private static RegistrationStatusResponse MapStatus(User user) => new()
        {
            RegistrationStep = user.RegistrationStep,
            AccountStatus = user.AccountStatus,
            VerificationStatus = user.VerificationStatus,
            RejectionReason = user.RejectionReason,
            CanReapplyAt = user.CanReapplyAt
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
