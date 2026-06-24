using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using AimPark.API.Enums;
using AimPark.API.Helpers;

namespace AimPark.API.Controllers
{

    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {

        private readonly AppDbContext _db;
        private readonly TokenService _tokenService;
        private readonly IConfiguration _configuration;
        public AuthController(AppDbContext db, TokenService token, IConfiguration configuration)
        {
            _db = db;
            _tokenService = token;
            _configuration = configuration;
        }
        //Register Endpoint
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            //Scenario 1 & 2 - Check missing/empty fields
            if (ValidationHelper.HasEmptyFields(dto.FullName, dto.Email, dto.Password))
                return BadRequest(new { message = "All fields are required." });

            //Scenario 3 - Check if email is already registered
            var EmailExists = await _db.Users
                .AnyAsync(u => u.Email == dto.Email);

            if (EmailExists)
                return BadRequest(new { message = "Email already in registered." });

            //Scenario 4 - Create new user as pending
            var user = new User
            {
                FullName = dto.FullName,
                Email = dto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
                Role = UserRole.User,
                Status = UserStatus.Incomplete,
                IsFirstLogin = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();


            //generate token after registration
            var token = _tokenService.GenerateToken(user);

            return Ok(new
            {
                message = "Step 1 complete. Please complete our registration",
                token = token
            });
        }


        //Register Vehicle Endpoint
        [HttpPost("register/vehicle")]
        [Authorize]
        public async Task<IActionResult> RegisterVehicle([FromBody] VehicleDTO dto)
        {
            //Get userId from JWT Token

            var userId = Guid.Parse(
                User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value
                );

            //check if user exists and is Incomplete
            var user = await _db.Users.FindAsync(userId);
            if (user is null)
                return NotFound("User not found.");

            if (user.Status != UserStatus.Incomplete)
                return BadRequest("Vehicle already submitted or registration complete");


            //Check if vehicle already exist for this user
            var vehicleExists = await _db.vehicles
                .AnyAsync(v => v.UserId == userId);

            if (vehicleExists)
                return BadRequest("Vehicle already registered for this user.");

            //check if plate number already exists
            var plateExists = await _db.vehicles
                .AnyAsync(v => v.PlateNumber == dto.PlateNumber);

            if (plateExists)
                return BadRequest("Plate number already registered.");

            //Validate fields
            if (ValidationHelper.HasEmptyFields(dto.PlateNumber, dto.VehicleType,
                                                dto.Brand, dto.Model, dto.Color))
                return BadRequest("All vehicle fields are required.");

            //save vehicle 
            var vehicle = new Vehicle
            {
                PlateNumber = dto.PlateNumber,
                VehicleType = dto.VehicleType,
                Brand = dto.Brand,
                Model = dto.Model,
                Color = dto.Color,
                UserId = userId,
            };

            _db.vehicles.Add(vehicle);
            await _db.SaveChangesAsync();

            return Ok("Step 2 complete. Please upload your documents");
        }


        //Register Documents Endpoint
        [HttpPost("register/documents")]
        [Authorize]
        [RequestSizeLimit(10 * 1024 * 1024)]
        [RequestFormLimits(MultipartBodyLengthLimit = 10 * 1024 * 1024)]
        public async Task<IActionResult> RegisterDocuments([FromForm] DocumentUploadDTO dto)
        {
            try
            {
                // Step 1 - get userId
                var userId = Guid.Parse(
                    User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)!.Value
                );

                // Step 2 - check user
                var user = await _db.Users.FindAsync(userId);
                if (user is null)
                    return NotFound(new { message = "User not found." });

                if (user.Status != UserStatus.Incomplete)
                    return BadRequest(new { message = "Documents already submitted." });

                // Step 3 - check vehicle
                var vehicleExists = await _db.vehicles
                    .AnyAsync(v => v.UserId == userId);

                if (!vehicleExists)
                    return BadRequest(new { message = "Please complete Step 2 first." });

                // Step 4 - validate files
                var allowedExtensions = new[] { ".jpg", ".jpeg", ".png", ".pdf" };
                var files = new[]
                {
            (dto.License, "License"),
            (dto.OR, "OR"),
            (dto.CR, "CR")
        };

                foreach (var (file, type) in files)
                {
                    if (file == null || file.Length == 0)
                        return BadRequest(new { message = $"{type} document is required." });

                    var ext = Path.GetExtension(file.FileName).ToLower();
                    if (!allowedExtensions.Contains(ext))
                        return BadRequest(new { message = $"{type} must be JPG, PNG or PDF." });

                    if (file.Length > 5 * 1024 * 1024)
                        return BadRequest(new { message = $"{type} must not exceed 5MB." });
                }

                // Step 5 - create folder
                var uploadPath = _configuration["FileStorage:UploadPath"]!;
                var userFolder = Path.Combine(uploadPath, userId.ToString());

                try
                {
                    Directory.CreateDirectory(userFolder);
                }
                catch (Exception folderEx)
                {
                    return StatusCode(500, new { message = "Folder creation failed.", error = folderEx.Message });
                }

                // Step 6 - save files
                var documents = new List<Document>();
                foreach (var (file, type) in files)
                {
                    try
                    {
                        var ext = Path.GetExtension(file.FileName).ToLower();
                        var fileName = $"{type.ToLower()}{ext}";
                        var filePath = Path.Combine(userFolder, fileName);

                        using var stream = new FileStream(filePath, FileMode.Create);
                        await file.CopyToAsync(stream);

                        documents.Add(new Document
                        {
                            Type = type,
                            FileName = fileName,
                            FilePath = filePath,
                            UserId = userId
                        });
                    }
                    catch (Exception fileEx)
                    {
                        return StatusCode(500, new { message = $"Failed saving {type}.", error = fileEx.Message });
                    }
                }

                // Step 7 - save to database
                try
                {
                    _db.Documents.AddRange(documents);
                    user.Status = UserStatus.Pending;
                    user.UpdatedAt = DateTime.UtcNow;
                    await _db.SaveChangesAsync();
                }
                catch (Exception dbEx)
                {
                    return StatusCode(500, new { message = "Database save failed.", error = dbEx.Message });
                }

                return Ok(new { message = "Registration complete! Please wait for admin approval." });
            }
            catch (Exception ex)
            {
                return StatusCode(500, new
                {
                    message = "Unexpected error.",
                    error = ex.Message,
                    inner = ex.InnerException?.Message
                });
            }
        }


        //Login Endpoint
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginDTO dto)
        {
            // validate fields
            if (ValidationHelper.HasEmptyFields(dto.Email, dto.Password))
                return BadRequest(new { message = "All fields are required." });

            // find user
            var user = await _db.Users
                .FirstOrDefaultAsync(u => u.Email == dto.Email);

            // Scenario 11 - email not found OR wrong password
            if (user is null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
                return Unauthorized(new { message = "Invalid credentials." });

            // Only reaches here if BOTH email AND password are correct
            switch (user.Status)
            {
                case UserStatus.Incomplete:
                    return Unauthorized(new
                    {
                        message = "Please complete your registration first."
                    });

                case UserStatus.Pending:
                    return Unauthorized(new
                    {
                        message = "Your account is waiting for admin approval."
                    });

                case UserStatus.Rejected:
                    return Unauthorized(new
                    {
                        message = "Your registration was rejected.",
                        reason = user.RejectionReason
                    });

                case UserStatus.Suspended:
                    return Unauthorized(new
                    {
                        message = "Your account has been suspended. Please contact admin."
                    });
            }

            // generate token
            var token = _tokenService.GenerateToken(user);

            return Ok(new
            {
                message = "Login successful.",
                token = token,
                role = user.Role,
                fullName = user.FullName
            });
        }
    }
}
