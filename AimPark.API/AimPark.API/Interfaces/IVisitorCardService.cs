using AimPark.API.DTOs;
using Microsoft.AspNetCore.Mvc;

namespace AimPark.API.Interfaces
{
    public interface IVisitorCardService
    {
        /// <summary>Every visitor card and where it is right now.</summary>
        Task<ActionResult<List<VisitorCardResponse>>> ListAsync(CancellationToken ct);

        Task<ActionResult<VisitorCardResponse>> AddAsync(AddVisitorCardDto dto, CancellationToken ct);

        /// <summary>
        /// Takes a card out of the visitor drawer, e.g. to give it to a new
        /// user. Its past visitors stay in the history. Refused while the card
        /// is out with a visitor.
        /// </summary>
        Task<ActionResult<object>> RemoveAsync(string rfidTagId, CancellationToken ct);
    }
}
