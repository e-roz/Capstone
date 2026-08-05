namespace AimPark.API.DTOs
{
    public class LogParkingEntryDto
    {
        // Either identifier can be used to find the user; at least one is required.
        public Guid? UserId { get; set; }
        public string? RfidTagId { get; set; }
        public Guid? SlotId { get; set; }

        // Which barrier the vehicle is standing at. Allocation prefers this
        // gate's bays — a driver already at Gate 1 cannot act on being told to
        // use Gate 2 unless Gate 1 is genuinely full.
        //
        // Supplied by hand from the admin panel during testing; in production
        // each reader is fixed to one gate, so the device's own identity fills
        // it in. Null means "no gate context" and falls back to steering by
        // spare capacity, which is what the in-app recommendation wants.
        public int? Gate { get; set; }
    }

    public class LogParkingExitDto
    {
        // Either identifies the session being closed. The admin panel picks a
        // LogId from the active-sessions list; a gate reader only ever knows the
        // card it just scanned, so it sends RfidTagId and the open session is
        // resolved from that.
        public Guid? LogId { get; set; }
        public string? RfidTagId { get; set; }
    }
}
