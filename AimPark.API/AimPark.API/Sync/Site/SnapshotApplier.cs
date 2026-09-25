using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Sync.Site
{
    /// <summary>
    /// Makes the site server's copy of the gate data match the cloud's.
    /// </summary>
    /// <remarks>
    /// The cloud owns who people are, their cards, suspensions, plates,
    /// devices, bays and rates, so those are overwritten. The site owns what
    /// happens at the gate — sessions, occupancy, when a device was last seen —
    /// so those are left alone.
    /// </remarks>
    public class SnapshotApplier
    {
        private readonly AppDbContext _db;
        private readonly SyncSuppression _suppression;

        public SnapshotApplier(AppDbContext db, SyncSuppression suppression)
        {
            _db = db;
            _suppression = suppression;
        }

        public async Task ApplyAsync(SiteSnapshot snapshot, CancellationToken ct)
        {
            // This is the cloud's data arriving; it must not go back into the outbox.
            _suppression.Active = true;

            // Users before vehicles and passes, which point at them.
            await ApplyUsersAsync(snapshot.Users, ct);
            await ApplyVehiclesAsync(snapshot.Vehicles, ct);
            await ApplyGateDevicesAsync(snapshot.GateDevices, ct);
            await ApplyRatesAsync(snapshot.ParkingRates, ct);
            await ApplySlotsAsync(snapshot.ParkingSlots, ct);
            await ApplyVisitorPassesAsync(snapshot.VisitorPasses, ct);
            await ApplyIncidentsAsync(snapshot.Incidents, snapshot.IncidentEvidence, ct);
        }

        private async Task ApplyUsersAsync(List<SyncUser> users, CancellationToken ct)
        {
            var local = await _db.Set<User>().ToDictionaryAsync(u => u.Id, ct);
            var incoming = users.ToDictionary(u => u.Id);
            var now = DateTime.UtcNow;

            // Email, card and student number are each unique. When a card moves
            // from one person to another, writing the new holder first would
            // collide with the old one, so everything that is about to move is
            // cleared out of the way in a save of its own first.
            var cleared = false;
            foreach (var user in local.Values)
            {
                if (!incoming.TryGetValue(user.Id, out var source))
                {
                    // Gone from the cloud. Kept, because parking logs point at it.
                    if (!user.IsDeleted || user.RfidTagId is not null)
                    {
                        user.IsDeleted = true;
                        user.DeletedAt ??= now;
                        user.RfidTagId = null;
                        user.StudentNumber = null;
                        cleared = true;
                    }
                    continue;
                }

                if (user.Email != source.Email ||
                    user.RfidTagId != source.RfidTagId ||
                    user.StudentNumber != source.StudentNumber)
                {
                    user.Email = $"moving-{user.Id:N}@site.invalid";
                    user.RfidTagId = null;
                    user.StudentNumber = null;
                    cleared = true;
                }
            }

            if (cleared)
                await _db.SaveChangesAsync(ct);

            foreach (var source in incoming.Values)
            {
                if (!local.TryGetValue(source.Id, out var user))
                {
                    user = new User { Id = source.Id };
                    _db.Set<User>().Add(user);
                }

                user.FullName = source.FullName;
                user.Email = source.Email;
                user.IsEmailVerified = source.IsEmailVerified;
                user.PasswordHash = source.PasswordHash;
                user.AuthProvider = source.AuthProvider;
                user.Role = source.Role;
                user.Affiliation = source.Affiliation;
                user.StudentNumber = source.StudentNumber;
                user.EnrollmentValidUntil = source.EnrollmentValidUntil;
                user.RegistrationStep = source.RegistrationStep;
                user.AccountStatus = source.AccountStatus;
                user.VerificationStatus = source.VerificationStatus;
                user.IsFirstLogin = source.IsFirstLogin;
                user.CreatedAt = source.CreatedAt;
                user.UpdatedAt = source.UpdatedAt;
                user.IsDeleted = source.IsDeleted;
                user.DeletedAt = source.DeletedAt;
                user.RfidTagId = source.RfidTagId;
                user.RfidStatus = source.RfidStatus;
                user.RfidSuspendedFrom = source.RfidSuspendedFrom;
                user.RfidSuspendedUntil = source.RfidSuspendedUntil;
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task ApplyVehiclesAsync(List<SyncVehicle> vehicles, CancellationToken ct)
        {
            var local = await _db.Set<Vehicle>().ToDictionaryAsync(v => v.Id, ct);
            var incoming = vehicles.ToDictionary(v => v.Id);

            // Plates are unique; same two-step as users.
            var cleared = false;
            foreach (var vehicle in local.Values)
            {
                if (!incoming.TryGetValue(vehicle.Id, out var source))
                {
                    _db.Set<Vehicle>().Remove(vehicle);
                    cleared = true;
                }
                else if (vehicle.PlateNumber != source.PlateNumber)
                {
                    vehicle.PlateNumber = "~" + vehicle.Id.ToString("N")[..12];
                    cleared = true;
                }
            }

            if (cleared)
                await _db.SaveChangesAsync(ct);

            foreach (var source in incoming.Values)
            {
                if (!local.TryGetValue(source.Id, out var vehicle))
                {
                    vehicle = new Vehicle { Id = source.Id };
                    _db.Set<Vehicle>().Add(vehicle);
                }

                vehicle.UserId = source.UserId;
                vehicle.PlateNumber = source.PlateNumber;
                vehicle.VehicleType = source.VehicleType;
                vehicle.Color = source.Color;
                vehicle.RegistrationValidThrough = source.RegistrationValidThrough;
                vehicle.RegistrationRenewalMonth = source.RegistrationRenewalMonth;
                vehicle.CreatedAt = source.CreatedAt;
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task ApplyGateDevicesAsync(List<GateDevice> devices, CancellationToken ct)
        {
            var local = await _db.Set<GateDevice>().ToDictionaryAsync(d => d.Id, ct);
            var incoming = devices.ToDictionary(d => d.Id);

            // A key the cloud no longer lists stops working here too.
            foreach (var device in local.Values.Where(d => !incoming.ContainsKey(d.Id)))
                device.IsRevoked = true;

            foreach (var source in incoming.Values)
            {
                if (!local.TryGetValue(source.Id, out var device))
                {
                    device = new GateDevice { Id = source.Id };
                    _db.Set<GateDevice>().Add(device);
                }

                device.Name = source.Name;
                device.Gate = source.Gate;
                device.DeviceType = source.DeviceType;
                device.ApiKeyHash = source.ApiKeyHash;
                device.ApiKeyPrefix = source.ApiKeyPrefix;
                device.IsRevoked = source.IsRevoked;
                device.CreatedAt = source.CreatedAt;
                // LastSeenAt stays: the devices talk to this server now, so
                // this copy is the one that knows.
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task ApplyRatesAsync(List<ParkingRate> rates, CancellationToken ct)
        {
            var local = await _db.Set<ParkingRate>().ToDictionaryAsync(r => r.Id, ct);
            var incoming = rates.ToDictionary(r => r.Id);

            // One rate per vehicle type is unique, so removals go first.
            var removed = local.Values.Where(r => !incoming.ContainsKey(r.Id)).ToList();
            if (removed.Count > 0)
            {
                _db.Set<ParkingRate>().RemoveRange(removed);
                await _db.SaveChangesAsync(ct);
            }

            foreach (var source in incoming.Values)
            {
                if (!local.TryGetValue(source.Id, out var rate))
                {
                    rate = new ParkingRate { Id = source.Id };
                    _db.Set<ParkingRate>().Add(rate);
                }

                rate.VehicleType = source.VehicleType;
                rate.RatePerHour = source.RatePerHour;
                rate.MinimumFee = source.MinimumFee;
                rate.UpdatedAt = source.UpdatedAt;
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task ApplySlotsAsync(List<ParkingSlot> slots, CancellationToken ct)
        {
            var local = await _db.Set<ParkingSlot>().ToDictionaryAsync(s => s.Id, ct);
            var incoming = slots.ToDictionary(s => s.Id);

            var occupied = (await _db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => l.ExitTime == null && l.SlotId != null)
                    .Select(l => l.SlotId!.Value)
                    .ToListAsync(ct))
                .ToHashSet();

            var usedByLogs = (await _db.Set<ParkingLog>().AsNoTracking()
                    .Where(l => l.SlotId != null)
                    .Select(l => l.SlotId!.Value)
                    .Distinct()
                    .ToListAsync(ct))
                .ToHashSet();

            var now = DateTime.UtcNow;

            foreach (var slot in local.Values.Where(s => !incoming.ContainsKey(s.Id)))
            {
                // A bay the admin removed. History still points at it, so it
                // is taken out of use rather than deleted.
                if (usedByLogs.Contains(slot.Id))
                {
                    slot.Status = ParkingSlotStatus.OutOfService;
                    slot.UpdatedAt = now;
                }
                else
                {
                    _db.Set<ParkingSlot>().Remove(slot);
                }
            }

            foreach (var source in incoming.Values)
            {
                var isNew = !local.TryGetValue(source.Id, out var slot);
                if (isNew)
                {
                    slot = new ParkingSlot { Id = source.Id, Status = ParkingSlotStatus.Available, UpdatedAt = now };
                    _db.Set<ParkingSlot>().Add(slot);
                }

                slot!.SlotCode = source.SlotCode;
                slot.Gate = source.Gate;
                slot.VehicleType = source.VehicleType;
                slot.CreatedAt = source.CreatedAt;

                // Whether a bay is in service is the admin's call, made in the
                // cloud. Whether a car is in it is this server's — it saw the
                // car arrive.
                ParkingSlotStatus status;
                if (source.Status == ParkingSlotStatus.OutOfService)
                    status = ParkingSlotStatus.OutOfService;
                else if (isNew || slot.Status == ParkingSlotStatus.OutOfService)
                    status = occupied.Contains(slot.Id) ? ParkingSlotStatus.Occupied : ParkingSlotStatus.Available;
                else
                    status = slot.Status;

                if (slot.Status != status)
                {
                    slot.Status = status;
                    slot.UpdatedAt = now;
                }
            }

            await _db.SaveChangesAsync(ct);
        }

        private async Task ApplyIncidentsAsync(
            List<Incident> incidents, List<IncidentEvidence> evidence, CancellationToken ct)
        {
            var local = await _db.Set<Incident>().ToDictionaryAsync(i => i.Id, ct);

            foreach (var source in incidents)
            {
                if (!local.TryGetValue(source.Id, out var incident))
                    _db.Set<Incident>().Add(source);
                // A guard edits here, an admin reviews in the cloud. Newer wins.
                else if (source.UpdatedAt > incident.UpdatedAt)
                    _db.Entry(incident).CurrentValues.SetValues(source);
            }

            await _db.SaveChangesAsync(ct);

            // Nothing is deleted: a report made here while offline is not in
            // the cloud's copy yet, and must survive until it has been sent.
            var knownEvidence = (await _db.Set<IncidentEvidence>().AsNoTracking()
                    .Select(e => e.Id)
                    .ToListAsync(ct))
                .ToHashSet();

            var added = false;
            foreach (var source in evidence.Where(e => !knownEvidence.Contains(e.Id)))
            {
                _db.Set<IncidentEvidence>().Add(source);
                added = true;
            }

            if (added)
                await _db.SaveChangesAsync(ct);
        }

        private async Task ApplyVisitorPassesAsync(List<VisitorPass> passes, CancellationToken ct)
        {
            var local = await _db.Set<VisitorPass>().ToDictionaryAsync(p => p.Id, ct);

            // Only one active pass per card. Closing old passes before opening
            // new ones keeps a card that was returned and lent out again from
            // colliding with itself.
            foreach (var group in new[]
                     {
                         passes.Where(p => p.Status != VisitorPassStatus.Active),
                         passes.Where(p => p.Status == VisitorPassStatus.Active)
                     })
            {
                foreach (var source in group)
                {
                    if (!local.TryGetValue(source.Id, out var pass))
                    {
                        _db.Set<VisitorPass>().Add(source);
                        continue;
                    }

                    // Guards issue and take back passes here too. Newer edit wins.
                    if (source.UpdatedAt > pass.UpdatedAt)
                        _db.Entry(pass).CurrentValues.SetValues(source);
                }

                await _db.SaveChangesAsync(ct);
            }
        }
    }
}
