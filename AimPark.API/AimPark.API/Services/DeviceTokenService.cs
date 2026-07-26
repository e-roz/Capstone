using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Services
{
    public class DeviceTokenService : IDeviceTokenService
    {
        private readonly IRepository<DeviceToken> _tokens;

        public DeviceTokenService(IRepository<DeviceToken> tokens)
        {
            _tokens = tokens;
        }

        // POST /api/notifications/device-token
        public async Task<ActionResult<object>> RegisterAsync(Guid userId, RegisterDeviceTokenDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Token))
                return new BadRequestObjectResult(new { message = "Device token is required." });

            var token = dto.Token.Trim();
            var existing = await _tokens.FindAsync(t => t.Token == token, ct);

            if (existing is not null)
            {
                // Same physical device, possibly a different account (shared/handed-over phone) —
                // re-point it at whoever is logged in now so the previous user stops receiving
                // notifications meant for someone else.
                existing.UserId = userId;
                existing.Platform = dto.Platform;
                existing.LastSeenAt = DateTime.UtcNow;
                _tokens.Update(existing);
            }
            else
            {
                await _tokens.AddAsync(new DeviceToken
                {
                    Id = Guid.NewGuid(),
                    UserId = userId,
                    Token = token,
                    Platform = dto.Platform,
                    CreatedAt = DateTime.UtcNow,
                    LastSeenAt = DateTime.UtcNow
                }, ct);
            }

            await _tokens.SaveAsync(ct);

            return new OkObjectResult(new { message = "Device registered for push notifications." });
        }

        // DELETE /api/notifications/device-token — called on logout
        public async Task<ActionResult<object>> UnregisterAsync(Guid userId, RegisterDeviceTokenDto dto, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Token))
                return new BadRequestObjectResult(new { message = "Device token is required." });

            var token = dto.Token.Trim();
            var existing = await _tokens.FindAsync(t => t.Token == token && t.UserId == userId, ct);

            if (existing is not null)
            {
                _tokens.Delete(existing);
                await _tokens.SaveAsync(ct);
            }

            return new OkObjectResult(new { message = "Device unregistered." });
        }
    }
}
