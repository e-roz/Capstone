using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class ParkingRate
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // null = default/fallback rate, applied when no vehicle-type-specific rate matches
        public VehicleType? VehicleType { get; set; }

        public decimal RatePerHour { get; set; }

        /// <summary>The least a completed session can cost.</summary>
        /// <remarks>
        /// Two reasons, and both are real. Parking is priced this way everywhere
        /// — a mall charges a flat first block, not five pesos for twenty
        /// minutes — and no card or e-wallet gateway in the country will accept
        /// a payment under twenty pesos, so per-minute billing produced bills
        /// that could not be paid online at all.
        /// </remarks>
        public decimal MinimumFee { get; set; } = 20.00m;

        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
    }
}
