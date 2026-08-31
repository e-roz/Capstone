namespace AimPark.API.DTOs
{
    public class UpsertParkingRateDto
    {
        // null = the default/fallback rate
        public string? VehicleType { get; set; }
        public decimal RatePerHour { get; set; }

        /// <summary>
        /// The least a session can cost. Omitted on older callers, which is why
        /// it is nullable rather than defaulted — a missing value has to leave
        /// the stored minimum alone, not quietly reset it to zero.
        /// </summary>
        public decimal? MinimumFee { get; set; }
    }
}
