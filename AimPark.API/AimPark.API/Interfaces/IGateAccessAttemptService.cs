using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// The guard's "needs a look" queue: taps the automatic RFID+ALPR check
    /// turned away, and haven't been acted on yet.
    /// </summary>
    public interface IGateAccessAttemptService
    {
        /// <summary>Unreviewed by default; pass includeReviewed for the full history.</summary>
        Task<ActionResult<GateAccessAttemptListResponse>> ListAsync(
            bool includeReviewed, int page, int pageSize, CancellationToken ct);

        /// <summary>
        /// Closes a flag without letting the vehicle in — the guard looked and
        /// decided it stays outside. A vehicle that *is* let in closes its own
        /// flag automatically when the manual entry is logged; this is only
        /// for the other outcome.
        /// </summary>
        Task<ActionResult<object>> DismissAsync(Guid attemptId, Guid reviewedByUserId, CancellationToken ct);
    }
}
