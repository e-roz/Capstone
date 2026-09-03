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

        // ── How this was settled ─────────────────────────────────────────────
        //
        // Null until it is. "Paid" alone was never enough to answer the question
        // an auditor actually asks, which is not whether the bill was settled but
        // where the money went and who can be asked about it.

        public PaymentMethod? Method { get; set; }

        /// <summary>Which gateway handled it: <c>PayMongo</c>, <c>Simulated</c>.</summary>
        /// <remarks>
        /// Written down rather than inferred from configuration, because
        /// configuration is the present tense and this row is the past: rows
        /// settled against the simulator must stay recognisable as such after a
        /// real provider is switched on.
        /// </remarks>
        public string? Provider { get; set; }

        /// <summary>
        /// The provider's own id for the checkout, and the only thing tying an
        /// incoming callback back to this row.
        /// </summary>
        public string? ProviderPaymentId { get; set; }

        /// <summary>
        /// What the payer can quote: a GCash reference number, or the provider's
        /// payment id. Shown on the receipt so a disputed payment can be looked
        /// up on both sides.
        /// </summary>
        public string? ReferenceNumber { get; set; }

        /// <summary>When the payer was sent to the provider.</summary>
        /// <remarks>
        /// A checkout nobody finished leaves the bill sitting in Processing.
        /// This is what says how long it has been sitting there.
        /// </remarks>
        public DateTime? CheckoutStartedAt { get; set; }

        /// <summary>
        /// The admin who took the cash, for the payments no gateway ever sees.
        /// </summary>
        /// <remarks>
        /// The counterpart of the merchant account: online money lands somewhere
        /// with a record attached, and cash lands in a person's hand. This is
        /// that record. Not a foreign key, matching the audit tables — the row
        /// has to stay readable after the account it names is archived.
        /// </remarks>
        public Guid? ConfirmedByUserId { get; set; }
    }
}
