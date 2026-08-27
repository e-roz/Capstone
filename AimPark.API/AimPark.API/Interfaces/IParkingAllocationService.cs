using AimPark.API.DTOs;
using AimPark.API.Enums;

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

        /// <summary>
        /// Claims a slot for a vehicle whose type is already known, rather than
        /// one looked up from a registered vehicle.
        /// </summary>
        /// <remarks>
        /// For visitors. They hold a lent card and no account, so there is no
        /// <c>Vehicle</c> row to read a type from — the pass carries it instead.
        ///
        /// <paramref name="userId"/> is used only for the tie-break that prefers
        /// the gate somebody used last; pass null for a visitor, who by
        /// definition has no last gate.
        /// </remarks>
        Task<SlotRecommendationResponse> ClaimForVehicleTypeAsync(
            VehicleType vehicleType, Guid? userId, int? atGate, CancellationToken ct);
    }
}
