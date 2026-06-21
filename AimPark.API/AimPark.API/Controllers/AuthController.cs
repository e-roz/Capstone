using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Controllers
{


    [ApiController]
    [Route("api/auth")]
    public class AuthController : ControllerBase
    {

        private readonly AppDbContext _db;
        public AuthController(AppDbContext db)
        {
            _db = db;
        }
        [HttpPost("register")]
        public async Task<IActionResult> Register([FromBody] RegisterDto dto)
        {
            //Scenario 1 & 2 - Check missing/empty fields
            if(string.IsNullOrEmpty(dto.FullName) ||
               string.IsNullOrEmpty(dto.Email) ||
               string.IsNullOrEmpty(dto.Password))
            {
                return BadRequest(new { message = "All fields are required." });
            }

            //Scenario 3 - Check if email is already registered
            var EmailExists = await _db.Users
                .AnyAsync(u => u.Email == dto.Email);

            if (EmailExists)
            {
                return BadRequest(new { message = "Email already in registered." });
            }

            //Scenario 4 - Create new user as pending
            var user = new User
            {
                FullName = dto.FullName,
                Email = dto.Email,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
                Role = "User",
                Status = "Pending",
                IsFirstLogin = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };

            _db.Users.Add(user);
            await _db.SaveChangesAsync();

            return Ok("Registration successful. Your account is pending approval.");
        }
    }
}
