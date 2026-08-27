using AimPark.API.Data;
using AimPark.API.DTOs;
using AimPark.API.Entities;
using AimPark.API.Enums;
using AimPark.API.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>
    /// Smart slot allocation.
    ///
    /// The facility is two gates of ten slots each — 2 four-wheel and 8
    /// motorcycle per gate. Within a gate the bays are metres apart, so ranking
    /// by proximity would be false precision; the decision that carries real
    /// value is <em>which gate</em>, because sending a rider to the gate with
    /// spare capacity saves them queueing at a full one.
    ///
    /// So the pick is two stages rather than a weighted score: choose the gate
    /// with the most free compatible slots, then take the lowest slot code
    /// within it. That is also the point of the design — it can be explained in
    /// one sentence, which a tuned scoring function or an ML model over twenty
    /// slots and no training data could not be.
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

        public ParkingAllocationService(AppDbContext db)
        {
            _db = db;
        }

        public async Task<SlotRecommendationResponse> RecommendAsync(Guid userId, CancellationToken ct)
        {
            var vehicleType = await GetVehicleTypeAsync(userId, ct);
            if (vehicleType is null)
                return NoVehicle();

            foreach (var tier in TiersFor(vehicleType.Value))
            {
                // No gate context — the driver has not committed to a barrier
                // yet, so steering them to the emptier gate is the whole point.
                var ranked = await RankCandidatesAsync(userId, tier, atGate: null, ct);
                if (ranked.Count == 0)
                    continue;

                var pick = ranked[0];
                return Assigned(pick, Alternatives(ranked, pick.Id),
                    BuildReason(pick, ranked, vehicleType.Value, tier, atGate: null));
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

        public async Task<SlotRecommendationResponse> ClaimForVehicleTypeAsync(
            VehicleType vehicleType, Guid? userId, int? atGate, CancellationToken ct)
        {
            foreach (var tier in TiersFor(vehicleType))
            {
                // Guid.Empty matches no parking log, so a visitor simply has no
                // "gate you used last" and falls through to spare capacity —
                // which is the right answer for somebody who has never been
                // here before.
                var ranked = await RankCandidatesAsync(
                    userId ?? Guid.Empty, tier, atGate, ct);

                foreach (var candidate in ranked.Take(MaxClaimAttempts))
                {
                    if (!await TryClaimAsync(candidate.Id, ct))
                        continue; // Another vehicle took it between the read and the write.

                    return Assigned(candidate, Alternatives(ranked, candidate.Id),
                        BuildReason(candidate, ranked, vehicleType, tier, atGate));
                }
            }

            return LotFull(vehicleType);
        }

        /// <summary>
        /// Which slot types this vehicle may use, best first. A motorcycle may
        /// fall back to a four-wheel bay, but only once every motorcycle bay is
        /// gone — otherwise the four scarce car slots get eaten while motorcycle
        /// slots sit empty. A car never fits a motorcycle bay, so it has no
        /// fallback at all.
        /// </summary>
        private static IEnumerable<VehicleType[]> TiersFor(VehicleType vehicleType) =>
            vehicleType == VehicleType.Motorcycle
                ? [[VehicleType.Motorcycle], [VehicleType.Car]]
                : [[VehicleType.Car]];

        private Task<VehicleType?> GetVehicleTypeAsync(Guid userId, CancellationToken ct) =>
            _db.Set<Vehicle>().AsNoTracking()
                .Where(v => v.UserId == userId)
                .Select(v => (VehicleType?)v.VehicleType)
                .FirstOrDefaultAsync(ct);

        /// <summary>
        /// Free slots of the given types, best first.
        ///
        /// When <paramref name="atGate"/> is set the vehicle is already at that
        /// barrier, so its bays come first and the other gate is only a fallback
        /// for when this one is full. When it is null the driver has not
        /// committed to a gate, and the ranking steers them to the emptier one.
        /// </summary>
        private async Task<List<ParkingSlot>> RankCandidatesAsync(
            Guid userId, VehicleType[] tier, int? atGate, CancellationToken ct)
        {
            var acceptable = tier.Select(t => (VehicleType?)t).ToArray();
            var now = DateTime.UtcNow;

            var free = await _db.Set<ParkingSlot>().AsNoTracking()
                .Where(s => (s.VehicleType == null || acceptable.Contains(s.VehicleType))
                         && s.Status == ParkingSlotStatus.Available)
                .ToListAsync(ct);

            if (free.Count == 0)
                return [];

            var lastGate = await _db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.UserId == userId && l.Slot != null)
                .OrderByDescending(l => l.EntryTime)
                .Select(l => (int?)l.Slot!.Gate)
                .FirstOrDefaultAsync(ct);

            // Stage 1: the gate the vehicle is standing at, if we know it —
            // otherwise the gate with the most spare capacity, breaking ties
            // toward the gate the driver used last.
            // Stage 2: within a gate, lowest slot code — deterministic and
            // demonstrable. Slots vacated seconds ago sort last but stay usable,
            // so a busy lot never strands someone on a technicality.
            return [.. free
                .GroupBy(s => s.Gate)
                .OrderBy(g => g.Key == atGate ? 0 : 1)
                .ThenByDescending(g => g.Count())
                .ThenBy(g => g.Key == lastGate ? 0 : 1)
                .ThenBy(g => g.Key)
                .SelectMany(g => g
                    .OrderBy(s => WasJustVacated(s, now) ? 1 : 0)
                    .ThenBy(s => s.SlotCode))];
        }

        /// <summary>
        /// Conditional update: the row only changes if it is still available at
        /// write time. A read-then-write here would hand the same slot to two
        /// vehicles scanning in at the same moment.
        /// </summary>
        private async Task<bool> TryClaimAsync(Guid slotId, CancellationToken ct)
        {
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

        private static SlotRecommendationResponse Assigned(
            ParkingSlot slot, List<SlotOptionResponse> alternatives, string reason) => new()
            {
                Result = AllocationResult.Assigned,
                SlotId = slot.Id,
                SlotCode = slot.SlotCode,
                Gate = slot.Gate,
                Alternatives = alternatives,
                Reason = reason
            };

        private static SlotRecommendationResponse NoVehicle() => new()
        {
            Result = AllocationResult.NoVehicleRegistered,
            Reason = "No registered vehicle found for this account."
        };

        private static SlotRecommendationResponse LotFull(VehicleType vehicleType) => new()
        {
            Result = AllocationResult.LotFull,
            Reason = vehicleType == VehicleType.Car
                ? "All four-wheel slots are taken."
                : "All slots are taken."
        };

        private static string BuildReason(
            ParkingSlot chosen, List<ParkingSlot> ranked, VehicleType vehicleType,
            VehicleType[] tier, int? atGate)
        {
            var overflow = vehicleType == VehicleType.Motorcycle && tier[0] == VehicleType.Car;
            var here = ranked.Count(s => s.Gate == chosen.Gate);
            var elsewhere = ranked.Count - here;

            // Diverted: the driver is at one barrier and is being sent to the
            // other. This is the one case they must not miss, so it leads.
            if (atGate is not null && chosen.Gate != atGate)
            {
                return overflow
                    ? $"Gate {atGate} is full and all motorcycle slots are taken — use the four-wheel bay {chosen.SlotCode} at Gate {chosen.Gate}."
                    : $"Gate {atGate} is full for your vehicle — proceed to Gate {chosen.Gate}.";
            }

            if (overflow)
                return $"All motorcycle slots are taken, so you have a four-wheel bay at Gate {chosen.Gate}.";

            if (atGate is not null)
                return $"Gate {chosen.Gate} has {here} free slot(s) for your vehicle.";

            if (elsewhere == 0)
                return $"Gate {chosen.Gate} is the only gate with space for your vehicle.";

            return $"Gate {chosen.Gate} has {here} free slot(s) for your vehicle versus {elsewhere} at the other gate.";
        }
    }
}
