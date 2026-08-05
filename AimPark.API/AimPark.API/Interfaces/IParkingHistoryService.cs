using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IParkingHistoryService
    {
        Task<ActionResult<ParkingHistoryResponse>> GetMyHistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct);
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
    }
}
