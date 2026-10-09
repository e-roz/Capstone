using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    /// <summary>Warnings that a bay may hold the wrong kind of vehicle.</summary>
    public interface IWrongBayService
    {
        /// <summary>
        /// A bay's sensor just read Occupied: raises a warning if the bay
        /// probably holds the wrong kind of vehicle. Best-effort and never
        /// throws: a sensor reading must not fail because of a warning.
        /// </summary>
        Task OnBayFilledAsync(Guid slotId, CancellationToken ct);

        /// <summary>A bay's sensor just read empty: its warning stops showing.</summary>
        Task OnBayEmptiedAsync(Guid slotId, CancellationToken ct);

        /// <summary>Warnings on bays that are still taken, except ones marked a false alarm.</summary>
        Task<ActionResult<List<WrongBayFlagResponse>>> ListLiveAsync(CancellationToken ct);

        Task<ActionResult<object>> ReviewAsync(Guid flagId, ReviewWrongBayFlagDto dto, Guid reviewerUserId, CancellationToken ct);
    }
}
