using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAdminAuditLogService
    {
        Task<ActionResult<AuditLogListResponse>> ListAsync(int page, int pageSize, string? action, CancellationToken ct);
    }
}
