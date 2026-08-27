using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    /// <summary>
    /// Vehicles added after registration is finished.
    /// </summary>
    /// <remarks>
    /// One RFID card covers every vehicle its holder registers, so a user who buys a
    /// second vehicle adds it here rather than repeating signup. The first vehicle
    /// still comes through <see cref="RegistrationService"/>, which keeps the signup
    /// flow a straight line.
    /// </remarks>
    public class VehicleService : IVehicleService
    {
        private readonly IRepository<User> _users;
        private readonly IRepository<Vehicle> _vehicles;
        private readonly IRepository<Document> _documents;
        private readonly IRepository<DocumentVerification> _verifications;
        private readonly IFileStorageService _fileStorage;
        private readonly IDocumentExtractionService _extraction;
        private readonly IPreScreeningService _preScreening;

        public VehicleService(
            IRepository<User> users,
            IRepository<Vehicle> vehicles,
            IRepository<Document> documents,
            IRepository<DocumentVerification> verifications,
            IFileStorageService fileStorage,
            IDocumentExtractionService extraction,
            IPreScreeningService preScreening)
        {
            _users = users;
            _vehicles = vehicles;
            _documents = documents;
            _verifications = verifications;
            _fileStorage = fileStorage;
            _extraction = extraction;
            _preScreening = preScreening;
        }

        public async Task<ActionResult<List<VehicleDetailResponse>>> GetMyVehiclesAsync(Guid userId, CancellationToken ct)
        {
            var vehicles = await _vehicles.GetAllAsync(v => v.UserId == userId, ct);

            return new OkObjectResult(vehicles
                .OrderBy(v => v.CreatedAt)
                .Select(Map)
                .ToList());
        }

        public async Task<ActionResult<object>> AddVehicleAsync(VehicleDTO dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            // Only an approved account may add vehicles. A pending applicant adding a
            // second vehicle would sidestep the review their first one is waiting for.
            if (user.AccountStatus != AccountStatus.Active)
                return new BadRequestObjectResult(new { message = "Your account must be approved before adding a vehicle." });

            // Brand and model are deliberately absent. Nothing reads them — the gate
            // matches on the plate and allocation on the type — so requiring them
            // only makes the form longer.
            if (ValidationHelper.HasEmptyFields(dto.PlateNumber, dto.VehicleType, dto.Color))
                return new BadRequestObjectResult(new { message = "Plate number, vehicle type and colour are required." });

            if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType))
                return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

            var plate = IdentifierNormalizer.NormalizePlate(dto.PlateNumber);
            if (plate.Length is < 4 or > 10)
                return new BadRequestObjectResult(new { message = "Plate number looks invalid." });

            // The plate is globally unique: ALPR looks one up and must get exactly one
            // vehicle back. Answered explicitly so the caller sees a message rather
            // than a database constraint error.
            if (await _vehicles.ExistsAsync(v => v.PlateNumber == plate, ct))
                return new BadRequestObjectResult(new { message = "That plate number is already registered." });

            var vehicle = new Vehicle
            {
                PlateNumber = plate,
                VehicleType = vehicleType,
                Brand = dto.Brand.Trim(),
                Model = dto.Model.Trim(),
                Color = dto.Color.Trim(),
                UserId = userId
            };

            await _vehicles.AddAsync(vehicle, ct);
            await _vehicles.SaveAsync(ct);

            return new OkObjectResult(new
            {
                message = "Vehicle added.",
                vehicle = Map(vehicle)
            });
        }

        /// <inheritdoc />
        /// <remarks>
        /// The same evidence registration demands, minus the documents that
        /// describe the person. The plate is never typed here for the reason it is
        /// never typed there: a typed plate proves nothing about a vehicle, and the
        /// gate matches on the plate alone, so anything a user could type is
        /// something they could type about somebody else's car.
        /// </remarks>
        public async Task<ActionResult<ScanResultResponse>> ScanVehicleDocumentsAsync(
            VehicleDocumentUploadDto dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.AccountStatus != AccountStatus.Active)
                return new BadRequestObjectResult(new
                {
                    message = "Your account must be approved before adding a vehicle."
                });

            var slots = new[]
            {
                (File: dto.OfficialReceipt, Type: DocumentType.OfficialReceipt, Ocr: dto.OfficialReceiptOcr),
                (File: dto.PlatePhoto, Type: DocumentType.PlatePhoto, Ocr: dto.PlatePhotoOcr)
            };

            var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
            foreach (var (file, type, _) in slots)
            {
                if (file is null || file.Length == 0)
                    return new BadRequestObjectResult(new { message = $"{Label(type)} is required." });

                var ext = Path.GetExtension(file.FileName).ToLowerInvariant();
                if (!allowedExtensions.Contains(ext))
                    return new BadRequestObjectResult(new { message = $"{Label(type)} must be JPG, PNG or PDF." });

                if (file.Length > 8 * 1024 * 1024)
                    return new BadRequestObjectResult(new { message = $"{Label(type)} must not exceed 8MB." });
            }

            var payloads = slots.ToDictionary(s => s.Type, s => OcrPayloadParser.Parse(s.Ocr));

            var diagnostics = new List<DocumentDiagnosisDto>();
            foreach (var (_, type, _) in slots)
            {
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
                    Message = OcrCleanup.MessageFor(reason, Label(type))
                });
            }

            // Added rather than replacing. The receipt on file belongs to the
            // vehicle registered at signup, and this one belongs to a different
            // vehicle — a reviewer looking back needs both, not the newer of two
            // documents that were never about the same thing.
            var documents = new List<Document>();
            foreach (var (file, type, _) in slots)
            {
                var filePath = await _fileStorage.SaveFileAsync(userId, type.ToString(), file!, ct);
                documents.Add(new Document
                {
                    Type = type,
                    FileName = Path.GetFileName(filePath),
                    FilePath = filePath,
                    Sha256 = await ComputeSha256Async(file!, ct),
                    UserId = userId
                });
            }

            await _documents.AddRangeAsync(documents, ct);

            // Person slots left null on purpose. This submission carries no RAF and
            // no licence, and a row claiming it could not read a name would report a
            // failure about documents it was never given.
            var extracted = _extraction.Extract(
                null,
                null,
                payloads[DocumentType.OfficialReceipt],
                payloads[DocumentType.PlatePhoto]);

            var verification = new DocumentVerification
            {
                UserId = userId,
                ExtractedPlateNumber = extracted.PlateNumber,
                ExtractedRegistrationExpiry = extracted.RegistrationExpiry,
                ExtractedPlatePhotoNumber = extracted.PlatePhotoNumber,
                Result = VerificationStatus.NotStarted
            };

            await _verifications.AddAsync(verification, ct);
            await _verifications.SaveAsync(ct);

            return new OkObjectResult(new ScanResultResponse
            {
                VerificationId = verification.Id,
                // Retakes are unlimited here, unlike registration. That limit exists
                // so an unreadable document cannot strand somebody mid-signup; a user
                // adding a second vehicle already has an account and can walk away
                // and come back, so there is nothing to fail open for.
                TriesLeft = 1,
                CanContinue = diagnostics.Count == 0,
                Diagnostics = diagnostics,
                Extracted = extracted
            });
        }

        /// <inheritdoc />
        public async Task<ActionResult<object>> ConfirmVehicleAsync(
            ConfirmVehicleDto dto, Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.AccountStatus != AccountStatus.Active)
                return new BadRequestObjectResult(new
                {
                    message = "Your account must be approved before adding a vehicle."
                });

            var verification = await _verifications.FindAsync(
                v => v.Id == dto.VerificationId && v.UserId == userId, ct);

            if (verification is null)
                return new NotFoundObjectResult(new { message = "That submission was not found." });

            if (verification.VehicleId is not null)
                return new BadRequestObjectResult(new { message = "This vehicle has already been added." });

            if (!Enum.TryParse<VehicleType>(dto.VehicleType, true, out var vehicleType)
                || !Enum.IsDefined(vehicleType))
                return new BadRequestObjectResult(new { message = "Invalid vehicle type." });

            if (ValidationHelper.HasEmptyFields(dto.Color))
                return new BadRequestObjectResult(new { message = "Choose the vehicle's colour." });

            // Straight from the receipt the server read. Nothing the client sent can
            // change it, which is the whole difference between this and typing it.
            var plate = IdentifierNormalizer.NormalizePlate(verification.ExtractedPlateNumber);

            if (plate.Length is < 4 or > 10)
                return new BadRequestObjectResult(new
                {
                    message = "No usable plate number could be read from the receipt. "
                        + "Photograph it again, keeping the plate number in frame."
                });

            if (await _vehicles.ExistsAsync(v => v.PlateNumber == plate, ct))
                return new BadRequestObjectResult(new
                {
                    message = $"Plate {plate} is already registered."
                });

            var expiry = dto.RegistrationExpiry ?? verification.ExtractedRegistrationExpiry;

            var vehicle = new Vehicle
            {
                PlateNumber = plate,
                VehicleType = vehicleType,
                Color = dto.Color.Trim(),
                RegistrationValidThrough = expiry,
                RegistrationRenewalMonth = RegistrationRenewal.RenewalMonthFromPlate(plate),
                UserId = userId
            };

            await _vehicles.AddAsync(vehicle, ct);

            verification.VehicleId = vehicle.Id;
            verification.ConfirmedPlateNumber = plate;
            verification.ConfirmedRegistrationExpiry = expiry;

            // Runs the same comparisons registration does, so the reviewer reads this
            // submission the way they read every other one.
            _preScreening.Evaluate(verification, user, vehicle);
            _verifications.Update(verification);

            await _vehicles.SaveAsync(ct);

            return new OkObjectResult(new
            {
                message = "Vehicle added.",
                vehicle = Map(vehicle)
            });
        }

        private static string Label(DocumentType type) => type switch
        {
            DocumentType.OfficialReceipt => "Official receipt",
            DocumentType.PlatePhoto => "Plate photo",
            _ => type.ToString()
        };

        private static async Task<string> ComputeSha256Async(IFormFile file, CancellationToken ct)
        {
            await using var stream = file.OpenReadStream();
            using var sha = System.Security.Cryptography.SHA256.Create();
            var hash = await sha.ComputeHashAsync(stream, ct);
            return Convert.ToHexString(hash).ToLowerInvariant();
        }

        private static VehicleDetailResponse Map(Vehicle v) => new()
        {
            Id = v.Id,
            PlateNumber = v.PlateNumber,
            VehicleType = v.VehicleType.ToString(),
            Brand = v.Brand,
            Model = v.Model,
            Color = v.Color,
            RegistrationValidThrough = v.RegistrationValidThrough,
            CreatedAt = v.CreatedAt
        };
    }
}
