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

        /// <summary>When the current rate and minimum took effect.</summary>
        public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;

        /// <summary>The hourly rate before the last change. Null if it never changed.</summary>
        /// <remarks>
        /// A car that came in before <see cref="UpdatedAt"/> keeps this rate
        /// until it leaves: the price is the one in force at entry, not the one
        /// in force at exit. Only one step back is kept, so a car inside through
        /// two changes pays the rate from just before the latest one.
        /// </remarks>
        public decimal? PreviousRatePerHour { get; set; }

        /// <summary>The minimum fee before the last change. Read with <see cref="PreviousRatePerHour"/>.</summary>
        public decimal? PreviousMinimumFee { get; set; }
    }
}
