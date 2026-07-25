using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IIncidentService
    {
        Task<ActionResult<object>> CreateAsync(CreateIncidentDto dto, Guid reporterUserId, CancellationToken ct);
        Task<ActionResult<IncidentListResponse>> GetMyIncidentsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<IncidentDetailResponse>> GetMyIncidentDetailAsync(Guid userId, Guid incidentId, CancellationToken ct);
        Task<ActionResult<IncidentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<IncidentDetailResponse>> GetDetailForAdminAsync(Guid incidentId, CancellationToken ct);
        Task<ActionResult<object>> ReviewAsync(Guid incidentId, Guid adminUserId, ReviewIncidentDto dto, CancellationToken ct);
    }
}
