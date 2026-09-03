namespace AimPark.API.Enums
{
    /// <summary>How a bill was actually settled.</summary>
    /// <remarks>
    /// Recorded rather than assumed: "paid" on its own cannot answer where the
    /// money is. Cash sits in a drawer and someone is accountable for it; the
    /// e-wallet methods land in the school's merchant account and the provider
    /// holds the receipt.
    /// </remarks>
    public enum PaymentMethod
    {
        Cash,
        GCash,
        Maya,
        Card
    }
}
