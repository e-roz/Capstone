using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IVisitorCardService
    {
        /// <summary>Every visitor card and where it is right now.</summary>
        Task<ActionResult<List<VisitorCardResponse>>> ListAsync(CancellationToken ct);

        Task<ActionResult<VisitorCardResponse>> AddAsync(AddVisitorCardDto dto, CancellationToken ct);

        /// <summary>Blocks a lost or broken card, or puts a found one back in use.</summary>
        Task<ActionResult<object>> SetBlockedAsync(string rfidTagId, bool blocked, string? note, CancellationToken ct);

        /// <summary>Only for a card that was never lent; one with history is blocked instead.</summary>
        Task<ActionResult<object>> RemoveAsync(string rfidTagId, CancellationToken ct);
    }
}
