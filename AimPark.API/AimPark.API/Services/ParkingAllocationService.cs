using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Helpers;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Smart slot allocation: the nearest free bay of the vehicle's own kind.
    ///
    /// The lot is one drive lane with a gate at each end (see
    /// <see cref="LotLayout"/>). A vehicle that taps in at a gate is given the
    /// free bay closest to that gate, whichever column it is in; bays the same
    /// distance away go to the lower slot number. That can be explained in one
    /// sentence, which a tuned scoring function or an ML model over eighteen
    /// slots and no training data could not be.
    ///
    /// The app has no gate to measure from, so it runs the same rule from the
    /// gate whose nearest free bay is closest, and tells the driver to enter
    /// there.
    ///
    /// There is no reservation concept. Slots are claimed at the barrier when
    /// the RFID is scanned; the in-app answer is advice only and writes nothing.
    /// </summary>
    public class ParkingAllocationService : IParkingAllocationService
    {
        /// <summary>
        /// A slot freed within this window is deprioritised — the previous car
        /// may still be manoeuvring out of it.
        /// </summary>
        private static readonly TimeSpan JustVacatedWindow = TimeSpan.FromMinutes(2);

        /// <summary>Cap on lost claim races before giving up on a tier.</summary>
        private const int MaxClaimAttempts = 3;

        private readonly AppDbContext _db;
        private readonly ISlotSensors _sensors;

        public ParkingAllocationService(AppDbContext db, ISlotSensors sensors)
        {
            _db = db;
            _sensors = sensors;
        }

        public async Task<SlotRecommendationResponse> RecommendAsync(Guid userId, CancellationToken ct)
        {
            var vehicleType = await GetVehicleTypeAsync(userId, ct);
            if (vehicleType is null)
                return NoVehicle();

            var room = await ParkingCapacity.LoadAsync(_db, ct);

            foreach (var tier in TiersFor(vehicleType.Value))
            {
                if (room.FreeOf(tier) <= 0)
                    continue;

                // No gate context — the driver has not committed to a barrier
                // yet, so the ranking picks the gate to send them to.
                var (ranked, gate) = await RankCandidatesAsync(userId, tier, atGate: null, ct);
                if (ranked.Count == 0)
                    continue;

                var pick = ranked[0];
                return Assigned(pick, gate, Alternatives(ranked, pick.Id),
                    BuildReason(pick, gate, atGate: null));
            }

            return LotFull(vehicleType.Value);
        }

        public async Task<SlotRecommendationResponse> ClaimForEntryAsync(
            Guid userId, int? atGate, CancellationToken ct)
        {
            var vehicleType = await GetVehicleTypeAsync(userId, ct);
            if (vehicleType is null)
                return NoVehicle();

            return await ClaimForVehicleTypeAsync(vehicleType.Value, userId, atGate, ct);
        }

        public Task<SlotRecommendationResponse> ClaimForVehicleTypeAsync(
            VehicleType vehicleType, Guid? userId, int? atGate, CancellationToken ct) =>
            ClaimFromTiersAsync(TiersFor(vehicleType), vehicleType, userId, atGate, ct);

        public async Task<SlotRecommendationResponse> ClaimAnyAsync(int? atGate, CancellationToken ct)
        {
            var claim = await ClaimFromTiersAsync(
                [[VehicleType.Car, VehicleType.Motorcycle]], VehicleType.Car, userId: null, atGate, ct);

            if (claim.Result == AllocationResult.LotFull)
                claim.Reason = "All slots are taken.";

            return claim;
        }

        private async Task<SlotRecommendationResponse> ClaimFromTiersAsync(
            IEnumerable<VehicleType[]> tiers, VehicleType vehicleType, Guid? userId, int? atGate, CancellationToken ct)
        {
            // Room is counted by cards: the lot is full when as many cars have
            // tapped in as there are working bays, whatever the sensors read.
            var room = await ParkingCapacity.LoadAsync(_db, ct);
            var roomButNoBay = false;

            foreach (var tier in tiers)
            {
                if (room.FreeOf(tier) <= 0)
                    continue;

                // Guid.Empty matches no parking log, so a visitor simply has no
                // "gate you used last" and falls through to spare capacity —
                // which is the right answer for somebody who has never been
                // here before.
                var (ranked, gate) = await RankCandidatesAsync(
                    userId ?? Guid.Empty, tier, atGate, ct);

                if (ranked.Count == 0)
                {
                    roomButNoBay = true;
                    continue;
                }

                foreach (var candidate in ranked.Take(MaxClaimAttempts))
                {
                    if (!await TryClaimAsync(candidate.Id, ct))
                        continue; // Another vehicle took it between the read and the write.

                    return Assigned(candidate, gate, Alternatives(ranked, candidate.Id),
                        BuildReason(candidate, gate, atGate));
                }
            }

            // Cards say there is room, but no bay reads free: someone is taking
            // two bays or parked outside one. The driver is let in anyway and
            // the guard is told about the gap (see ParkingMismatchMonitor).
            return roomButNoBay ? NoBayToGive() : LotFull(vehicleType);
        }

        /// <summary>
        /// Which slot types this vehicle may use. Only its own kind: when the
        /// motorcycle bays are full no more motorcycles come in, and when the
        /// car bays are full no more cars do.
        /// </summary>
        private static IEnumerable<VehicleType[]> TiersFor(VehicleType vehicleType) =>
            [[vehicleType]];

        private Task<VehicleType?> GetVehicleTypeAsync(Guid userId, CancellationToken ct) =>
            _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == userId)
                .Select(v => (VehicleType?)v.VehicleType)
                .FirstOrDefaultAsync(ct);

        /// <summary>
        /// Free slots of the given types, best first, and the gate they were
        /// measured from.
        ///
        /// When <paramref name="atGate"/> is set the vehicle is already at that
        /// barrier, so distance is measured from it. When it is null the driver
        /// has not committed to a gate, and <see cref="EntryGateFor"/> picks one.
        /// </summary>
        private async Task<(List<ParkingSlot> Ranked, int Gate)> RankCandidatesAsync(
            Guid userId, VehicleType[] tier, int? atGate, CancellationToken ct)
        {
            var acceptable = tier.Select(t => (VehicleType?)t).ToArray();

            // A bay given to a car still inside is never offered again, even
            // while its sensor sees it empty.
            var held = await ParkingCapacity.HeldBaysAsync(_db, ct);

            var free = await _db.Set<ParkingSlot>().AsNoTracking()
                .Where(s => (s.VehicleType == null || acceptable.Contains(s.VehicleType))
                         && s.Status == ParkingSlotStatus.Available
                         && !held.Contains(s.Id))
                .ToListAsync(ct);

            if (free.Count == 0)
                return ([], atGate ?? 1);

            var gate = atGate ?? EntryGateFor(free, await LastGateAsync(userId, ct));
            return (Rank(free, gate, DateTime.UtcNow), gate);
        }

        /// <summary>
        /// Nearest to <paramref name="gate"/> first; bays the same distance away
        /// go to the lower slot number (M7 before M10). Slots vacated seconds ago
        /// sort last but stay usable, so a busy lot never strands someone on a
        /// technicality.
        /// </summary>
        public static List<ParkingSlot> Rank(IEnumerable<ParkingSlot> free, int gate, DateTime now) =>
            [.. free
                .OrderBy(s => WasJustVacated(s, now) ? 1 : 0)
                .ThenBy(s => LotLayout.DistanceFrom(gate, s.SlotCode))
                .ThenBy(s => LotLayout.NumberOf(s.SlotCode))
                .ThenBy(s => s.SlotCode, StringComparer.OrdinalIgnoreCase)];

        /// <summary>
        /// For a driver with no gate yet: the gate whose nearest free bay is
        /// closest. A tie goes to the gate they used last, then to Gate 1.
        /// </summary>
        public static int EntryGateFor(IReadOnlyCollection<ParkingSlot> free, int? lastGate) =>
            new[] { 1, 2 }
                .OrderBy(g => free.Min(s => LotLayout.DistanceFrom(g, s.SlotCode)))
                .ThenBy(g => g == lastGate ? 0 : 1)
                .ThenBy(g => g)
                .First();

        private Task<int?> LastGateAsync(Guid userId, CancellationToken ct) =>
            _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId == userId && l.Gate != null)
                .OrderByDescending(l => l.EntryTime)
                .Select(l => l.Gate)
                .FirstOrDefaultAsync(ct);

        /// <summary>
        /// Conditional update: the row only changes if it is still available at
        /// write time. A read-then-write here would hand the same slot to two
        /// vehicles scanning in at the same moment.
        /// </summary>
        private async Task<bool> TryClaimAsync(Guid slotId, CancellationToken ct)
        {
            // A bay with a sensor is only recommended, never marked: the
            // driver may park in another, and that bay's sensor reports it.
            // Being given to this session keeps it from the next car.
            if (_sensors.Watches(slotId))
                return await _db.Set<ParkingSlot>()
                    .AnyAsync(s => s.Id == slotId && s.Status == ParkingSlotStatus.Available, ct);

            var rows = await _db.Set<ParkingSlot>()
                .Where(s => s.Id == slotId && s.Status == ParkingSlotStatus.Available)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(s => s.Status, ParkingSlotStatus.Occupied)
                    .SetProperty(s => s.UpdatedAt, DateTime.UtcNow), ct);

            return rows == 1;
        }

        private static bool WasJustVacated(ParkingSlot slot, DateTime now) =>
            now - slot.UpdatedAt < JustVacatedWindow;

        private static List<SlotOptionResponse> Alternatives(List<ParkingSlot> ranked, Guid chosenId) =>
            [.. ranked
                .Where(s => s.Id != chosenId)
                .Take(3)
                .Select(s => new SlotOptionResponse
                {
                    SlotId = s.Id,
                    SlotCode = s.SlotCode,
                    Gate = s.Gate
                })];

        /// <param name="gate">The gate to enter by, which may not be the one whose column the bay is in.</param>
        private static SlotRecommendationResponse Assigned(
            ParkingSlot slot, int gate, List<SlotOptionResponse> alternatives, string reason) => new()
            {
                Result = AllocationResult.Assigned,
                SlotId = slot.Id,
                SlotCode = slot.SlotCode,
                Gate = gate,
                Alternatives = alternatives,
                Reason = reason
            };

        private static SlotRecommendationResponse NoVehicle() => new()
        {
            Result = AllocationResult.NoVehicleRegistered,
            Reason = "No registered vehicle found for this account."
        };

        private static SlotRecommendationResponse NoBayToGive() => new()
        {
            Result = AllocationResult.Assigned,
            Reason = "No bay reads free right now. Park in any open bay."
        };

        private static SlotRecommendationResponse LotFull(VehicleType vehicleType) => new()
        {
            Result = AllocationResult.LotFull,
            Reason = vehicleType == VehicleType.Car
                ? "All four-wheel slots are taken."
                : "All motorcycle slots are taken."
        };

        private static string BuildReason(ParkingSlot chosen, int gate, int? atGate) =>
            atGate is not null
                ? $"{chosen.SlotCode} is the nearest free slot to Gate {gate} for your vehicle."
                : $"Enter at Gate {gate}: {chosen.SlotCode} is the nearest free slot for your vehicle.";
    }
}
