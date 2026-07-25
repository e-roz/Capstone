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

        // Admin/Security account that recorded this entry — stands in for the RFID gate hardware for now
        public Guid LoggedByUserId { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    }
}
