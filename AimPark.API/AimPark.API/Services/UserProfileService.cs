using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    public class UserProfileService : IUserProfileService
    {
        private readonly IRepository<User> _users;

        public UserProfileService(IRepository<User> users)
        {
            _users = users;
        }

        // GET /api/account/profile
        public async Task<ActionResult<MyProfileResponse>> GetMyProfileAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            return new OkObjectResult(new MyProfileResponse
            {
                UserId = user.Id,
                FullName = user.FullName,
                Email = user.Email,
                Role = user.Role.ToString(),
                Affiliation = user.Affiliation.ToString(),
                StudentNumber = user.StudentNumber,
                Section = user.Section,
                EnrollmentValidUntil = user.EnrollmentValidUntil,
                AccountStatus = user.AccountStatus.ToString(),
                CreatedAt = user.CreatedAt
            });
        }

        // PUT /api/account/profile
        public async Task<ActionResult<object>> UpdateProfileAsync(Guid userId, UpdateProfileDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.FullName))
                return new BadRequestObjectResult(new { message = "Full name is required." });

            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            user.FullName = dto.FullName.Trim();
            user.UpdatedAt = DateTime.UtcNow;

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Profile updated." });
        }

        // POST /api/account/change-password
        public async Task<ActionResult<object>> ChangePasswordAsync(Guid userId, ChangePasswordDto dto, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.PasswordHash is null)
                return new BadRequestObjectResult(new { message = "This account signs in via an external provider and has no password to change." });

            if (string.IsNullOrEmpty(dto.CurrentPassword) || !BCrypt.Net.BCrypt.Verify(dto.CurrentPassword, user.PasswordHash))
                return new UnauthorizedObjectResult(new { message = "Current password is incorrect." });

            if (string.IsNullOrWhiteSpace(dto.NewPassword) || dto.NewPassword.Length < 8)
                return new BadRequestObjectResult(new { message = "New password must be at least 8 characters." });

            user.PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.NewPassword, workFactor: 12);
            user.UpdatedAt = DateTime.UtcNow;

            _users.Update(user);
            await _users.SaveAsync(ct);

            return new OkObjectResult(new { message = "Password changed." });
        }

        // GET /api/account/access-status
        public async Task<ActionResult<AccessStatusResponse>> GetAccessStatusAsync(Guid userId, CancellationToken ct)
        {
            var user = await _users.FindAsync(u => u.Id == userId, ct);
            if (user is null)
                return new NotFoundObjectResult(new { message = "User not found." });

            if (user.RfidStatus == RfidStatus.Suspended
                && user.RfidSuspendedUntil is not null
                && user.RfidSuspendedUntil <= DateTime.UtcNow)
            {
                // Temporary suspension has expired — lazily reactivate.
                user.RfidStatus = RfidStatus.Active;
                user.RfidSuspendedUntil = null;
                user.UpdatedAt = DateTime.UtcNow;

                _users.Update(user);
                await _users.SaveAsync(ct);
            }

            return new OkObjectResult(new AccessStatusResponse
            {
                RfidTagId = user.RfidTagId,
                RfidStatus = user.RfidStatus.ToString(),
                AccountStatus = user.AccountStatus.ToString()
            });
        }
    }
}
