using AimPark.API.DTOs;

namespace AimPark.API.Interfaces
{
    public interface ISlotConfirmationService
    {
        /// <summary>
        /// Records the bay a driver says they parked in. The sensors never do
        /// this for them: a sensor can report a bay that is empty, so only the
        /// driver's own word is stored as the confirmed bay. Final: a second
        /// confirm for the same session is refused.
        /// </summary>
        Task<ConfirmSlotResponse> ConfirmAsync(Guid userId, ConfirmSlotRequest request, CancellationToken ct);

        /// <summary>
        /// An administrator moves a confirmed bay to the right one, with a
        /// reason. The driver's own answer and every correction are kept.
        /// </summary>
        Task<CorrectBayResponse> CorrectAsync(Guid adminUserId, Guid logId, CorrectBayRequest request, CancellationToken ct);

        /// <summary>The driver's confirm and every correction since. Null when the session does not exist.</summary>
        Task<BayConfirmHistoryResponse?> GetHistoryAsync(Guid logId, CancellationToken ct);
    }
}
