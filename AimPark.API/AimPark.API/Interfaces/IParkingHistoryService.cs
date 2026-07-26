using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IParkingHistoryService
    {
        Task<ActionResult<ParkingHistoryResponse>> GetMyHistoryAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<List<ActiveParkingSessionResponse>>> ListActiveSessionsAsync(CancellationToken ct);
        Task<ActionResult<object>> LogEntryAsync(LogParkingEntryDto dto, Guid loggedByUserId, CancellationToken ct);
        Task<ActionResult<object>> LogExitAsync(LogParkingExitDto dto, Guid loggedByUserId, CancellationToken ct);
    }
}
