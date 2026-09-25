using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Cloud
{
    /// <summary>Reads everything a gate decision needs, for the site to keep a copy of.</summary>
    public class SnapshotBuilder
    {
        private readonly AppDbContext _db;

        public SnapshotBuilder(AppDbContext db)
        {
            _db = db;
        }

        public async Task<SiteSnapshot> BuildAsync(CancellationToken ct)
        {
            var users = await _db.Set<User>().AsNoTracking()
                .Select(u => new SyncUser
                {
                    Id = u.Id,
                    FullName = u.FullName,
                    Email = u.Email,
                    IsEmailVerified = u.IsEmailVerified,
                    // Staff sign in at the guard post, and must be able to when
                    // the internet is down. Drivers never sign in to the site
                    // server, so their hashes have no reason to leave the cloud.
                    PasswordHash = u.Role == UserRole.User ? null : u.PasswordHash,
                    AuthProvider = u.AuthProvider,
                    Role = u.Role,
                    Affiliation = u.Affiliation,
                    StudentNumber = u.StudentNumber,
                    EnrollmentValidUntil = u.EnrollmentValidUntil,
                    RegistrationStep = u.RegistrationStep,
                    AccountStatus = u.AccountStatus,
                    VerificationStatus = u.VerificationStatus,
                    IsFirstLogin = u.IsFirstLogin,
                    CreatedAt = u.CreatedAt,
                    UpdatedAt = u.UpdatedAt,
                    IsDeleted = u.IsDeleted,
                    DeletedAt = u.DeletedAt,
                    RfidTagId = u.RfidTagId,
                    RfidStatus = u.RfidStatus,
                    RfidSuspendedFrom = u.RfidSuspendedFrom,
                    RfidSuspendedUntil = u.RfidSuspendedUntil
                })
                .ToListAsync(ct);

            var vehicles = await _db.Set<Vehicle>().AsNoTracking()
                .Select(v => new SyncVehicle
                {
                    Id = v.Id,
                    UserId = v.UserId,
                    PlateNumber = v.PlateNumber,
                    VehicleType = v.VehicleType,
                    Color = v.Color,
                    RegistrationValidThrough = v.RegistrationValidThrough,
                    RegistrationRenewalMonth = v.RegistrationRenewalMonth,
                    CreatedAt = v.CreatedAt
                })
                .ToListAsync(ct);

            return new SiteSnapshot
            {
                GeneratedAt = DateTime.UtcNow,
                Users = users,
                Vehicles = vehicles,
                VisitorPasses = await _db.Set<VisitorPass>().AsNoTracking().ToListAsync(ct),
                GateDevices = await _db.Set<GateDevice>().AsNoTracking().ToListAsync(ct),
                ParkingSlots = await _db.Set<ParkingSlot>().AsNoTracking().ToListAsync(ct),
                ParkingRates = await _db.Set<ParkingRate>().AsNoTracking().ToListAsync(ct),
                Incidents = await _db.Set<Incident>().AsNoTracking().ToListAsync(ct),
                IncidentEvidence = await _db.Set<IncidentEvidence>().AsNoTracking().ToListAsync(ct)
            };
        }
    }
}
