using System.Security.Cryptography;
using System.Text;
using AimPark.API.Auth;
using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    public class GateDeviceService : IGateDeviceService
    {
        /// <summary>Bytes of randomness per key. 256 bits is not brute-forceable.</summary>
        private const int KeyBytes = 32;

        /// <summary>Characters of the key kept in clear, purely for display.</summary>
        private const int PrefixLength = 12;

        private readonly AppDbContext _db;

        public GateDeviceService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<ActionResult<CreatedGateDeviceResponse>> CreateAsync(
            CreateGateDeviceDto dto, bool callerIsAdmin, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(dto.Name))
                return new BadRequestObjectResult(new { message = "Device name is required." });

            // 0 is the enrollment desk rather than a barrier — see
            // ApiKeyDefaults.EnrollmentGate. Negative numbers are nothing.
            if (dto.Gate < ApiKeyDefaults.EnrollmentGate)
                return new BadRequestObjectResult(new
                {
                    message = "Gate must be 1 or greater, or 0 for an enrollment desk reader."
                });

            if (WhoMayRegister(dto, callerIsAdmin) is { } refusal)
                return new ObjectResult(new { message = refusal }) { StatusCode = StatusCodes.Status403Forbidden };

            var apiKey = GenerateKey();

            var device = new GateDevice
            {
                Id = Guid.NewGuid(),
                Name = dto.Name.Trim(),
                Gate = dto.Gate,
                DeviceType = dto.DeviceType,
                ApiKeyHash = Hash(apiKey),
                ApiKeyPrefix = apiKey[..PrefixLength],
                IsRevoked = false,
                CreatedAt = DateTime.UtcNow
            };

            _db.Set<GateDevice>().Add(device);
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new CreatedGateDeviceResponse
            {
                DeviceId = device.Id,
                Name = device.Name,
                Gate = device.Gate,
                DeviceType = device.DeviceType,
                ApiKey = apiKey
            });
        }

        public async Task<ActionResult<List<GateDeviceResponse>>> ListAsync(CancellationToken ct)
        {
            var devices = await _db.Set<GateDevice>().AsNoTracking()
                .OrderBy(d => d.Gate)
                .ThenBy(d => d.Name)
                .Select(d => new GateDeviceResponse
                {
                    DeviceId = d.Id,
                    Name = d.Name,
                    Gate = d.Gate,
                    DeviceType = d.DeviceType,
                    ApiKeyPrefix = d.ApiKeyPrefix,
                    IsRevoked = d.IsRevoked,
                    LastSeenAt = d.LastSeenAt,
                    CreatedAt = d.CreatedAt
                })
                .ToListAsync(ct);

            return new OkObjectResult(devices);
        }

        public async Task<ActionResult<object>> RevokeAsync(Guid deviceId, CancellationToken ct)
        {
            var device = await _db.Set<GateDevice>().FirstOrDefaultAsync(d => d.Id == deviceId, ct);
            if (device is null)
                return new NotFoundObjectResult(new { message = "Device not found." });

            device.IsRevoked = true;
            await _db.SaveChangesAsync(ct);

            return new OkObjectResult(new { message = "Device revoked." });
        }

        public async Task<GateDevice?> AuthenticateAsync(string apiKey, CancellationToken ct)
        {
            if (string.IsNullOrWhiteSpace(apiKey))
                return null;

            var hash = Hash(apiKey);

            var device = await _db.Set<GateDevice>()
                .FirstOrDefaultAsync(d => d.ApiKeyHash == hash && !d.IsRevoked, ct);

            if (device is null)
                return null;

            // Cheap liveness signal for the admin list. Only written when it has
            // actually moved on, so a busy gate is not writing on every scan.
            var now = DateTime.UtcNow;
            if (device.LastSeenAt is null || now - device.LastSeenAt > TimeSpan.FromMinutes(1))
            {
                device.LastSeenAt = now;
                await _db.SaveChangesAsync(ct);
            }

            return device;
        }

        /// <summary>
        /// Who registers what. Returns why this caller may not, or null.
        /// </summary>
        /// <remarks>
        /// The admin registers the two devices that live off the gates: the
        /// site server, whose key has to exist before the guard post can sign
        /// anyone in at all, and the enrollment desk reader in their own
        /// office. Everything on a gate is Security's — they install it and
        /// work next to it. Both may revoke anything, so the admin can still
        /// cut off a device a guard should not have made.
        /// </remarks>
        private static string? WhoMayRegister(CreateGateDeviceDto dto, bool callerIsAdmin)
        {
            var offGate = dto.DeviceType == GateDeviceType.SiteServer
                          || (dto.DeviceType == GateDeviceType.RfidReader && dto.Gate == ApiKeyDefaults.EnrollmentGate);

            if (dto.DeviceType == GateDeviceType.SiteServer && dto.Gate != ApiKeyDefaults.EnrollmentGate)
                return "The site server is registered with gate 0.";

            if (dto.DeviceType == GateDeviceType.AlprCamera && dto.Gate < 1)
                return "A camera watches a gate. Use gate 1 or higher.";

            if (callerIsAdmin && !offGate)
                return "Gate readers and cameras are registered by Security at the guard post.";

            if (!callerIsAdmin && offGate)
                return "Only an administrator can register the site server or the enrollment desk reader.";

            return null;
        }

        private static string GenerateKey()
        {
            var bytes = RandomNumberGenerator.GetBytes(KeyBytes);
            // URL-safe, no padding — survives being pasted into firmware,
            // config files and shell commands without escaping.
            var body = Convert.ToBase64String(bytes)
                .Replace("+", "-")
                .Replace("/", "_")
                .TrimEnd('=');

            return ApiKeyDefaults.KeyPrefix + body;
        }

        private static string Hash(string apiKey) =>
            Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(apiKey)));
    }
}
