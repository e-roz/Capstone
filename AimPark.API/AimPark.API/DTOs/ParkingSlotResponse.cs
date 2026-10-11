namespace AimPark.API.DTOs
{
    public class ParkingAvailabilityResponse
    {
        public List<ParkingSlotResponse> Slots { get; set; } = [];
        public int TotalSlots { get; set; }

        /// <summary>
        /// Free bays: in-service bays less the cars inside the lot, not the
        /// green bays. See <see cref="Services.ParkingCapacity"/>.
        /// </summary>
        public int AvailableSlots { get; set; }

        public int AvailableCars { get; set; }
        public int AvailableMotorcycles { get; set; }

        /// <summary>
        /// When the guard post last reported, by the cloud's clock. The phone
        /// shows this as the age of the count instead of its own fetch time,
        /// which only says when the phone last asked. Null when the cloud has
        /// not heard from the guard post since it started.
        /// </summary>
        public DateTime? LastHeardAt { get; set; }

        /// <summary>
        /// The guard post has gone quiet, so every bay is reported as No signal
        /// and nothing is counted free. What the bays last said proves nothing
        /// once the thing reading them is off.
        /// </summary>
        public bool FeedPaused { get; set; }
    }

    public class ParkingSlotResponse
    {
        public Guid SlotId { get; set; }
        public string SlotCode { get; set; } = string.Empty;
        public int Gate { get; set; }
        public string? VehicleType { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}
