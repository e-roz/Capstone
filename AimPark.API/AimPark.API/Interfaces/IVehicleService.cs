using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IVehicleService
    {
        Task<ActionResult<List<VehicleDetailResponse>>> GetMyVehiclesAsync(Guid userId, CancellationToken ct);

        /// <summary>
        /// Reads the receipt for a vehicle being added, and returns what it said
        /// for the user to check.
        /// </summary>
        Task<ActionResult<ScanResultResponse>> ScanVehicleDocumentsAsync(VehicleDocumentUploadDto dto, Guid userId, CancellationToken ct);

        /// <summary>
        /// Commits the vehicle from a scan the user has agreed to.
        /// </summary>
        Task<ActionResult<object>> ConfirmVehicleAsync(ConfirmVehicleDto dto, Guid userId, CancellationToken ct);
    }
}
