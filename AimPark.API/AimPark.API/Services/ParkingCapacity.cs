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
    /// The free count is the bays a driver could pull into right now.
    /// </summary>
    /// <remarks>
    /// A bay is free when it reads Available and no car still inside was given
    /// it. So the count follows the sensors — a car set down in a bay takes it,
    /// tap or no tap — and a car that tapped in but hasn't parked yet still
    /// takes the bay it was given. Occupied, No signal and Out of service bays
    /// are never free: a sensor that has stopped reading proves nothing.
    ///
    /// A car that parks in another bay than the one it was given holds both
    /// until its exit tap. That errs toward "full", never toward sending a
    /// driver to a bay that is taken. A session that was given no bay at all
    /// takes room from the total only.
    /// </remarks>
    public static class ParkingCapacity
    {
        /// <param name="bays">Every bay: its type (null = any vehicle), status, and whether an open session was given it.</param>
        /// <param name="unplaced">Open sessions that were given no bay.</param>
        public static ParkingRoom Of(
            IEnumerable<(VehicleType? Type, ParkingSlotStatus Status, bool Held)> bays, int unplaced = 0)
        {
            var bayList = bays.ToList();

            int FreeFor(VehicleType? type) =>
                bayList.Count(b => b.Type == type && b.Status == ParkingSlotStatus.Available && !b.Held);

            var cars = FreeFor(VehicleType.Car);
            var motorcycles = FreeFor(VehicleType.Motorcycle);
            var anyVehicle = FreeFor(null);

            return new ParkingRoom(Math.Max(0, cars + motorcycles + anyVehicle - unplaced), cars, motorcycles);
        }

        /// <summary>The lot as it stands: every bay, and every car still inside.</summary>
        public static async Task<ParkingRoom> LoadAsync(AppDbContext db, CancellationToken ct)
        {
            var bays = await db.Set<ParkingSlot>().AsNoTracking()
                .Select(s => new { s.Id, s.VehicleType, s.Status })
                .ToListAsync(ct);

            var sessions = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null)
                .Select(l => l.SlotId)
                .ToListAsync(ct);

            var held = sessions.OfType<Guid>().ToHashSet();
            var unplaced = sessions.Count(id => id is null);

            return Of(bays.Select(b => (b.VehicleType, b.Status, held.Contains(b.Id))), unplaced);
        }

        /// <summary>The bays an open session was given: never offered to the next car.</summary>
        public static Task<List<Guid>> HeldBaysAsync(AppDbContext db, CancellationToken ct) =>
            db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null && l.SlotId != null)
                .Select(l => l.SlotId!.Value)
                .ToListAsync(ct);
    }
}
