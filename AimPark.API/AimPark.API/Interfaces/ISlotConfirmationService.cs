using AimPark.API.DTOs;

namespace AimPark.API.Interfaces
{
    public interface ISlotConfirmationService
    {
        /// <summary>
        /// Records the bay a driver says they parked in. The sensors never do
        /// this for them: a sensor can report a bay that is empty, so only the
        /// driver's own word is stored as the confirmed bay. Safe to call again
        /// to change the bay.
        /// </summary>
        Task<ConfirmSlotResponse> ConfirmAsync(Guid userId, ConfirmSlotRequest request, CancellationToken ct);
    }
}
