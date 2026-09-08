using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IAlprService
    {
        /// <summary>
        /// Records what the ALPR camera saw, or — when the plate is empty —
        /// treats the call as a bare liveness ping and records nothing.
        /// </summary>
        Task<ActionResult<AlprReadingResponse>> SubmitReadingAsync(
            SubmitAlprReadingDto dto, Guid deviceId, CancellationToken ct);
    }
}
