namespace AimPark.API.DTOs
{
    public class ParkingAvailabilityResponse
    {
        public List<ParkingSlotResponse> Slots { get; set; } = [];
        public int TotalSlots { get; set; }

        /// <summary>
        /// Room by cards: bays with a working sensor less the cars inside the
        /// lot, not the green bays. See <see cref="Services.ParkingCapacity"/>.
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

        /// <summary>Cars that tapped in and have not tapped out.</summary>
        public int UsersInside { get; set; }

        /// <summary>Bays a working sensor reads as occupied.</summary>
        public int SensorsDetected { get; set; }

        /// <summary>Bays with a working sensor: the total the two counts above are read against.</summary>
        public int LiveBays { get; set; }

        /// <summary>Bays whose sensor has stopped reading. While any is silent, the two counts cannot be compared.</summary>
        public int NoSignalBays { get; set; }
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
