using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IVehicleService
    {
        Task<ActionResult<List<VehicleDetailResponse>>> GetMyVehiclesAsync(Guid userId, CancellationToken ct);
        Task<ActionResult<object>> AddVehicleAsync(VehicleDTO dto, Guid userId, CancellationToken ct);
    }
}
