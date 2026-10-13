using AimPark.API.DTOs;
using AimPark.API.Enums;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    /// <summary>
    /// The read side of the System Logs module. Administrative action logs stay
    /// on <see cref="IAdminAuditLogService"/>, which already owned them.
    /// </summary>
    public interface IAdminLogService
    {
        Task<ActionResult<RfidAccessLogListResponse>> ListRfidAccessAsync(
            int page,
            int pageSize,
            string? search,
            int? gate,
            VehicleType? vehicleType,
            bool? visitor,
            DateTime? from,
            DateTime? to,
            CancellationToken ct);

        Task<ActionResult<UserActivityLogListResponse>> ListUserActivityAsync(
            int page,
            int pageSize,
            string? activity,
            CancellationToken ct);

        Task<ActionResult<SystemErrorLogListResponse>> ListErrorsAsync(
            int page,
            int pageSize,
            CancellationToken ct);
    }
}
