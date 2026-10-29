using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IParkingHistoryService
    {
        Task<ActionResult<ParkingHistoryResponse>> GetMyHistoryAsync(Guid userId, Guid? vehicleId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<List<ActiveParkingSessionResponse>>> ListActiveSessionsAsync(CancellationToken ct);
        /// <summary>
        /// Records a vehicle entering. Exactly one of the two caller ids is set:
        /// a staff account working the admin panel, or a gate device reporting
        /// an RFID scan.
        /// </summary>
        Task<ActionResult<object>> LogEntryAsync(
            LogParkingEntryDto dto, Guid? loggedByUserId, Guid? loggedByDeviceId, CancellationToken ct);

        Task<ActionResult<object>> LogExitAsync(
            LogParkingExitDto dto, Guid? loggedByUserId, Guid? loggedByDeviceId, CancellationToken ct);

        /// <summary>
        /// Prices the caller's open session up to now and returns the bill to pay
        /// it with, so they can pay before driving to the gate.
        /// </summary>
        Task<ActionResult<PayAheadResponse>> PayAheadAsync(Guid userId, Guid logId, CancellationToken ct);
    }
}
