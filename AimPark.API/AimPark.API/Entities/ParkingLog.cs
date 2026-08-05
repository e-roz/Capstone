namespace AimPark.API.Entities
{
    public class ParkingLog
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        //Foreign key to ParkingSlot (nullable — slot may not be tracked at log time)
        public Guid? SlotId { get; set; }
        public ParkingSlot? Slot { get; set; }

        public DateTime EntryTime { get; set; }
        public DateTime? ExitTime { get; set; }

        // Exactly one of these identifies who recorded the entry: a staff
        // account working the admin panel, or a gate device reporting a scan.
        public Guid? LoggedByUserId { get; set; }
        public Guid? LoggedByDeviceId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
