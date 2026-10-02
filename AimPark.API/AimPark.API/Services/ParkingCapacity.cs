using AimPark.API.Data;
using AimPark.API.Entities;
using AimPark.API.Enums;
using Microsoft.EntityFrameworkCore;

namespace AimPark.API.Services
{
    /// <summary>How many bays are free, overall and per bay type.</summary>
    public record ParkingRoom(int Free, int FreeCars, int FreeMotorcycles)
    {
        /// <summary>Free bays of these types, e.g. the tiers a vehicle may use.</summary>
        public int FreeOf(IEnumerable<VehicleType> types) =>
            types.Distinct().Sum(t => t == VehicleType.Car ? FreeCars : FreeMotorcycles);
    }

    /// <summary>
    /// The free count is cars inside the lot, not green bays.
    /// </summary>
    /// <remarks>
    /// A bay's colour is what its sensor sees, and the bay a driver is given at
    /// the gate is only a recommendation: they may park in another, or be
    /// driving there, or (on the miniature) be lifted out without tapping out.
    /// Through all of that the car is still inside until its exit tap.
    ///
    /// So per bay type, the bays taken are the larger of the open sessions
    /// given a bay of that type and the bays a car is seen in. One car is never
    /// counted twice, wherever it parks; a car that entered but isn't parked
    /// still counts; and a car seen in a bay with no session (a manual entry
    /// still to come, a mistake) still counts. Out-of-service bays aren't room.
    /// A session that was given no bay at all takes room from the total only.
    /// </remarks>
    public static class ParkingCapacity
    {
        /// <param name="bays">Every bay: its type (null = any vehicle) and status.</param>
        /// <param name="sessionBayTypes">One per open session: the type of the bay it was given, or null when it was given none.</param>
        public static ParkingRoom Of(
            IEnumerable<(VehicleType? Type, ParkingSlotStatus Status)> bays,
            IEnumerable<(bool HasBay, VehicleType? Type)> sessionBayTypes)
        {
            var bayList = bays.ToList();
            var sessions = sessionBayTypes.ToList();

            int FreeFor(VehicleType? type)
            {
                var inService = bayList.Where(b => b.Type == type && b.Status != ParkingSlotStatus.OutOfService).ToList();
                var seen = inService.Count(b => b.Status == ParkingSlotStatus.Occupied);
                var held = sessions.Count(s => s.HasBay && s.Type == type);
                return Math.Max(0, inService.Count - Math.Max(seen, held));
            }

            var cars = FreeFor(VehicleType.Car);
            var motorcycles = FreeFor(VehicleType.Motorcycle);
            var anyVehicle = FreeFor(null);
            var unplaced = sessions.Count(s => !s.HasBay);

            return new ParkingRoom(Math.Max(0, cars + motorcycles + anyVehicle - unplaced), cars, motorcycles);
        }

        /// <summary>The lot as it stands: every bay, and every car still inside.</summary>
        public static async Task<ParkingRoom> LoadAsync(AppDbContext db, CancellationToken ct)
        {
            var bays = await db.Set<ParkingSlot>().AsNoTracking()
                .Select(s => new { s.VehicleType, s.Status })
                .ToListAsync(ct);

            var sessions = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null)
                .Select(l => new { HasBay = l.SlotId != null, Type = l.Slot != null ? l.Slot.VehicleType : null })
                .ToListAsync(ct);

            return Of(bays.Select(b => (b.VehicleType, b.Status)),
                      sessions.Select(s => (s.HasBay, s.Type)));
        }

        /// <summary>The bays an open session was given: never offered to the next car.</summary>
        public static Task<List<Guid>> HeldBaysAsync(AppDbContext db, CancellationToken ct) =>
            db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null && l.SlotId != null)
                .Select(l => l.SlotId!.Value)
                .ToListAsync(ct);
    }
}
