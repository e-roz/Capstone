using AimPark.API.Entities;
using AimPark.API.Enums;

namespace AimPark.API.Interfaces
{
    /// <summary>Where to send the payer, and what the provider calls this attempt.</summary>
    public record GatewayCheckout(string ProviderPaymentId, string CheckoutUrl);

    /// <summary>
    /// One settlement message from a provider, already stripped of whatever
    /// shape that particular provider wraps it in.
    /// </summary>
    public record GatewayEvent(
        string ProviderPaymentId,
        bool Paid,
        string? ReferenceNumber,
        PaymentMethod? Method);

    /// <summary>
    /// The only thing the payment code knows about the outside world.
    /// </summary>
    /// <remarks>
    /// Deliberately two methods wide. Everything that makes a payment system
    /// worth trusting — the states a bill moves through, refusing to settle the
    /// same message twice, who confirmed a cash payment, what the receipt says —
    /// is ours and is tested without a provider existing at all. What a provider
    /// adds is a checkout page and a callback, and that is all this interface
    /// asks for.
    ///
    /// So the simulator is not a mock bolted on for a demo: it is one
    /// implementation of this, and PayMongo is another. Turning a live account
    /// on is a configuration value, not a rewrite.
    /// </remarks>
    public interface IPaymentGateway
    {
        /// <summary>Recorded on every settlement, so old rows say who handled them.</summary>
        string Name { get; }

        /// <summary>Opens a checkout with the provider and returns where to send the payer.</summary>
        Task<GatewayCheckout> CreateCheckoutAsync(
            PaymentTransaction payment,
            string description,
            CancellationToken ct = default);

        /// <summary>
        /// Reads a callback, or refuses it. Returns false for anything whose
        /// signature does not check out, and for the provider's own chatter about
        /// events this system does not act on.
        /// </summary>
        /// <remarks>
        /// The verification lives with the provider rather than in the controller
        /// because it is provider-specific in every detail: which header carries
        /// the signature, what exactly is signed, and which of several events
        /// means "the money arrived".
        /// </remarks>
        bool TryReadEvent(string rawBody, IDictionary<string, string> headers, out GatewayEvent gatewayEvent);
    }
}
