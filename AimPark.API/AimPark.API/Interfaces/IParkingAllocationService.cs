using AimPark.API.DTOs;

namespace AimPark.API.Interfaces
{
    public interface IParkingAllocationService
    {
        /// <summary>
        /// Suggests the best free slot for a user's registered vehicle.
        /// Read-only — nothing is held or written, so the answer can go stale
        /// between the suggestion and the driver arriving at the barrier.
        /// </summary>
        Task<SlotRecommendationResponse> RecommendAsync(Guid userId, CancellationToken ct);

        /// <summary>
        /// Picks a slot and takes it in the same operation, for use when a
        /// vehicle is actually being logged in at the gate. Safe to call
        /// concurrently — losing a race falls through to the next candidate
        /// rather than double-booking a bay.
        /// </summary>
        /// <param name="atGate">
        /// The barrier the vehicle is standing at, whose bays are preferred.
        /// Null when there is no gate context.
        /// </param>
        Task<SlotRecommendationResponse> ClaimForEntryAsync(
            Guid userId, int? atGate, CancellationToken ct);
    }
}
