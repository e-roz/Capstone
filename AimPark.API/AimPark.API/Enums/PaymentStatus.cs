namespace AimPark.API.Enums
{
    public enum PaymentStatus
    {
        Pending,

        /// <summary>
        /// The payer has been sent to the provider and nothing has come back yet.
        /// </summary>
        /// <remarks>
        /// Between "owes money" and "has paid" there is a real minute where the
        /// student is inside GCash and the school knows nothing. Without a state
        /// for it the bill either lies (Paid before the money moved) or invites a
        /// second payment (still Pending while one is in flight).
        /// </remarks>
        Processing,

        Paid,
        Waived
    }
}
