using AimPark.API.Enums;

namespace AimPark.API.Entities
{
    public class PaymentTransaction
    {
        public Guid Id { get; set; } = Guid.NewGuid();

        // Exactly one of ParkingLogId/ViolationId is set, enforced in PaymentService.
        public PaymentSource Source { get; set; } = PaymentSource.ParkingFee;

        //Foreign key to ParkingLog (one transaction per completed session, when Source == ParkingFee)
        public Guid? ParkingLogId { get; set; }
        public ParkingLog? ParkingLog { get; set; }

        //Foreign key to Violation (when Source == ViolationPenalty)
        public Guid? ViolationId { get; set; }
        public Violation? Violation { get; set; }

        //Foreign key to User
        public Guid UserId { get; set; }
        public User User { get; set; } = null!;

        public int DurationMinutes { get; set; }

        // Snapshot of the rate applied at calculation time — later rate changes never
        // retroactively alter an already-computed bill.
        public decimal RatePerHourApplied { get; set; }
        public decimal AmountDue { get; set; }

        public PaymentStatus Status { get; set; } = PaymentStatus.Pending;

        // When settlement is expected. Without a deadline a pending fee reads as
        // optional, which is how violation penalties went unpaid indefinitely.
        public DateTime? DueAt { get; set; }

        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? PaidAt { get; set; }
    }
}
