using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IParkingSlotService
    {
        Task<ActionResult<ParkingAvailabilityResponse>> GetAvailabilityAsync(CancellationToken ct);
        Task<ActionResult<ParkingAvailabilityResponse>> ListAllAsync(CancellationToken ct);
        Task<ActionResult<object>> CreateAsync(UpsertParkingSlotDto dto, CancellationToken ct);
        Task<ActionResult<object>> UpdateStatusAsync(Guid slotId, UpdateSlotStatusDto dto, CancellationToken ct);
    }
}
