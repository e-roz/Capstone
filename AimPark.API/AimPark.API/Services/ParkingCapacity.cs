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
    /// The two numbers the Parking screen sets side by side, and the bays they
    /// are counted against.
    /// </summary>
    /// <param name="UsersInside">Open sessions: cars that tapped in and have not tapped out.</param>
    /// <param name="SensorsDetected">Bays a working sensor reads as occupied.</param>
    /// <param name="TotalBays">Bays with a working sensor. A bay that lost its signal, or is out of service, is not in it.</param>
    /// <param name="NoSignalBays">Bays whose sensor has stopped reading.</param>
    public record LotCount(int UsersInside, int SensorsDetected, int TotalBays, int NoSignalBays)
    {
        /// <summary>
        /// Whether the two numbers can be compared at all. A bay with no signal
        /// may well hold a car, so while one is silent the gap proves nothing.
        /// </summary>
        public bool Comparable => NoSignalBays == 0;
    }

    /// <summary>
    /// Room is counted by cards, not by sensors: the lot is full when as many
    /// cars have tapped in as there are working bays.
    /// </summary>
    /// <remarks>
    /// A car taking two bays, or parked outside any bay, no longer turns the
    /// next driver away; the sensor count is shown beside the tap count so the
    /// guard sees the gap and goes to look (see <see cref="LotCount"/>).
    ///
    /// A bay counts toward the total only while its sensor is reading. One
    /// that has lost its signal drops out at once, and comes back with the
    /// sensor. Out-of-service bays are never in it.
    ///
    /// Cars and motorcycles are counted apart: a motorcycle fills motorcycle
    /// bays first, and only the overflow takes a four-wheel bay. A session
    /// whose vehicle type is not known takes room from the total only.
    /// </remarks>
    public static class ParkingCapacity
    {
        /// <param name="bays">Every bay: its type (null = any vehicle) and status.</param>
        /// <param name="sessions">The vehicle type of every car still inside (null = unknown).</param>
        public static ParkingRoom Of(
            IEnumerable<(VehicleType? Type, ParkingSlotStatus Status)> bays,
            IEnumerable<VehicleType?> sessions)
        {
            var live = bays.Where(b => IsLive(b.Status)).ToList();
            var inside = sessions.ToList();

            var liveCars = live.Count(b => b.Type == VehicleType.Car);
            var liveMotorcycles = live.Count(b => b.Type == VehicleType.Motorcycle);

            var cars = inside.Count(t => t == VehicleType.Car);
            var motorcycles = inside.Count(t => t == VehicleType.Motorcycle);
            var overflow = Math.Max(0, motorcycles - liveMotorcycles);

            return new ParkingRoom(
                Free: Math.Max(0, live.Count - inside.Count),
                FreeCars: Math.Max(0, liveCars - cars - overflow),
                FreeMotorcycles: Math.Max(0, liveMotorcycles - motorcycles));
        }

        public static LotCount CountOf(IEnumerable<ParkingSlotStatus> bays, int usersInside)
        {
            var list = bays.ToList();
            var live = list.Where(IsLive).ToList();
            return new LotCount(
                usersInside,
                live.Count(s => s == ParkingSlotStatus.Occupied),
                live.Count,
                list.Count(s => s == ParkingSlotStatus.NoSignal));
        }

        private static bool IsLive(ParkingSlotStatus status) =>
            status is not (ParkingSlotStatus.OutOfService or ParkingSlotStatus.NoSignal);

        /// <summary>The lot as it stands: every bay, and every car still inside.</summary>
        public static async Task<ParkingRoom> LoadAsync(AppDbContext db, CancellationToken ct)
        {
            var (bays, sessions) = await ReadAsync(db, ct);
            return Of(bays.Select(b => (b.Type, b.Status)), sessions);
        }

        /// <summary>Users inside against sensors detected, for the Parking screen and the guard alert.</summary>
        public static async Task<LotCount> LoadCountAsync(AppDbContext db, CancellationToken ct)
        {
            var (bays, sessions) = await ReadAsync(db, ct);
            return CountOf(bays.Select(b => b.Status), sessions.Count);
        }

        private static async Task<(List<(VehicleType? Type, ParkingSlotStatus Status)> Bays, List<VehicleType?> Sessions)> ReadAsync(
            AppDbContext db, CancellationToken ct)
        {
            var bays = await db.Set<ParkingSlot>().AsNoTracking()
                .Select(s => new { s.VehicleType, s.Status })
                .ToListAsync(ct);

            // The type that came in; failing that, the type of the bay it was
            // given, which is all a session with no camera reading can say.
            var sessions = await db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null)
                .Select(l => l.VehicleType ?? (l.Slot == null ? null : l.Slot.VehicleType))
                .ToListAsync(ct);

            return ([.. bays.Select(b => (b.VehicleType, b.Status))], sessions);
        }

        /// <summary>The bays an open session was given: never offered to the next car.</summary>
        public static Task<List<Guid>> HeldBaysAsync(AppDbContext db, CancellationToken ct) =>
            db.Set<ParkingLog>().AsNoTracking()
                .Where(l => l.ExitTime == null && l.SlotId != null)
                .Select(l => l.SlotId!.Value)
                .ToListAsync(ct);
    }
}
