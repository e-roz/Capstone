using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IIncidentService
    {
        Task<ActionResult<object>> CreateAsync(CreateIncidentDto dto, Guid reporterUserId, CancellationToken ct);
        Task<ActionResult<IncidentListResponse>> GetMyIncidentsAsync(Guid userId, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<IncidentDetailResponse>> GetMyIncidentDetailAsync(Guid userId, Guid incidentId, CancellationToken ct);

        /// <summary>
        /// Corrects a report the user filed. Only while it is still Submitted —
        /// once an admin has begun reviewing, changing the text underneath them
        /// would make their notes refer to something that no longer exists.
        /// </summary>
        Task<ActionResult<object>> UpdateMyIncidentAsync(Guid userId, Guid incidentId, UpdateIncidentDto dto, CancellationToken ct);

        /// <summary>
        /// Retracts a report. Kept as a Withdrawn row rather than deleted, so the
        /// audit trail still shows it was filed.
        /// </summary>
        Task<ActionResult<object>> WithdrawMyIncidentAsync(Guid userId, Guid incidentId, CancellationToken ct);
        Task<ActionResult<IncidentListResponse>> ListAllAsync(string? status, int page, int pageSize, CancellationToken ct);
        Task<ActionResult<IncidentDetailResponse>> GetDetailForAdminAsync(Guid incidentId, CancellationToken ct);
        Task<ActionResult<object>> ReviewAsync(Guid incidentId, Guid adminUserId, ReviewIncidentDto dto, CancellationToken ct);
    }
}
