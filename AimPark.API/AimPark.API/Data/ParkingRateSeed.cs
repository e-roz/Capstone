using AimPark.API.Entities;

namespace AimPark.API.Data
{
    // Fixed seed data: one default hourly rate so fee calculation always has something to
    // apply out of the box. Guid and timestamp are static so `dotnet ef migrations add`
    // produces a stable diff. Editable later via the rate-management endpoint.
    public static class ParkingRateSeed
    {
        private static readonly DateTime SeedTimestamp = new(2026, 7, 23, 0, 0, 0, DateTimeKind.Utc);

        public static ParkingRate[] GetSeedRates() =>
        [
            new ParkingRate
            {
                Id = new Guid("00000000-0000-0000-0000-0000000000f1"),
                VehicleType = null,
                RatePerHour = 15.00m,
                UpdatedAt = SeedTimestamp
            }
        ];
    }
}
